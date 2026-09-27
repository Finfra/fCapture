#!/bin/bash
# fCapture TDD 재생목록 러너 — tdd/playlist.md 의 신규 목표를 id 단위로 검증
# Usage: tdd/tdd-test.sh [id ...]      (인자 없으면 전 목표를 재생목록 순서로)
# 전제:
#   * bin/fCapture 빌드됨 (FCAPTURE_BIN 으로 바꿀 수 있음)
#   * Screen Recording 권한이 있는 GUI 세션 — SSH 직접 실행은 권한이 없어 캡처 목표가 exit 2 로 실패
# 격리: HOME·CFFIXED_USER_HOME 을 임시 폴더로 바꿔 사용자 ~/.fCapture 상태(ID 카운터·기본 결과형식)를 건드리지 않음
#   homeDirectoryForCurrentUser 는 HOME 을 무시한다 — CFFIXED_USER_HOME 이 있어야 격리된다 (jma 실측: HOME 만으론 실제 카운터 017 을 읽음)
# 실패를 삼키지 않는다 — 한 목표라도 실패하면 exit 1

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${FCAPTURE_BIN:-$ROOT/bin/fCapture}"
VERSION_FILE="$ROOT/VERSION"
SCREEN_TARGET="screen:1"

if [[ ! -x "$BIN" ]]; then
    echo "❌ 실행 파일 없음: $BIN (먼저 빌드)" >&2
    exit 1
fi

WORK="$(mktemp -d /tmp/fcapture-tdd.XXXXXX)"
REAL_HOME="$HOME"   # 공식 빌드(swift build)는 실제 HOME 의 툴체인 캐시로 돌린다 — 격리는 fCapture 실행에만
export HOME="$WORK/home"
export CFFIXED_USER_HOME="$HOME"
mkdir -p "$HOME"

PASS=0
FAIL=0
FAILED_IDS=()

# 실행 결과: RC·OUT(stdout 파일)·ERR(stderr 파일)
run() {
    OUT="$WORK/last.out"
    ERR="$WORK/last.err"
    "$BIN" "$@" >"$OUT" 2>"$ERR"
    RC=$?
}

now() { perl -MTime::HiRes=time -e 'printf "%.3f\n", time'; }

# 목표 하나 안의 개별 단언. 실패 사유를 남기고 목표 실패 플래그를 세운다
CASE_OK=1
check() {
    local desc="$1"; shift
    if "$@"; then
        echo "    ✅ $desc"
    else
        echo "    ❌ $desc"
        echo "       rc=$RC stdout=[$(head -c 300 "$OUT")] stderr=[$(tail -c 300 "$ERR" | tr '\n' ' ')]"
        CASE_OK=0
    fi
}

begin() { CASE_OK=1; echo "▶ $1"; }
finish() {
    if [[ $CASE_OK -eq 1 ]]; then
        PASS=$((PASS + 1)); echo "  ✅ PASS $1"
    else
        FAIL=$((FAIL + 1)); FAILED_IDS+=("$1"); echo "  ❌ FAIL $1"
    fi
}

stdout_empty() { [[ ! -s "$OUT" ]]; }
stdout_lines() { [[ "$(grep -c '' "$OUT")" == "$1" ]]; }
stderr_has() { grep -q "$1" "$ERR"; }
stdout_has() { grep -q "$1" "$OUT"; }
stdout_lacks() { ! grep -q "$1" "$OUT"; }
rc_is() { [[ "$RC" == "$1" ]]; }
# Mach-O 에 섹션이 있는가 (universal 은 슬라이스마다 나온다 — 하나라도 있으면 참)
# otool 출력을 먼저 받는다 — 파이프로 grep -q 에 물리면 pipefail 환경에서 SIGPIPE 오판 (deploy-brew.sh 동일)
has_section() { local cmds; cmds="$(otool -l "$1")"; grep -q "sectname $2" <<<"$cmds"; }
lacks_section() { ! has_section "$@"; }

# 1. -v/--version 출력이 VERSION 파일 값과 일치
t_version_flag() {
    begin version-flag
    local expected="fCapture $(tr -d '[:space:]' <"$VERSION_FILE")"
    for flag in -v --version; do
        run "$flag"
        check "$flag → exit 0" rc_is 0
        check "$flag → '$expected'" [ "$(cat "$OUT")" == "$expected" ]
    done
    finish version-flag
}

# 2. 유효하지 않은 target → 에러 메시지 + exit 1
t_invalid_target_exit1() {
    begin invalid-target-exit1
    run -t invalid_target -p "$WORK/out-invalid" -R onlyPath
    check "exit 1" rc_is 1
    check "stderr 에 target 오류 메시지" stderr_has "유효하지 않은 target"
    check "stdout 비어 있음" stdout_empty
    finish invalid-target-exit1
}

# 3. 실패 케이스는 exit 0 + 빈 stdout 이 아니라 exit 1
t_failure_exit_code_nonzero() {
    begin failure-exit-code-nonzero
    # /dev/null 은 파일이라 그 아래 폴더를 만들 수 없다
    run -t "$SCREEN_TARGET" -p /dev/null/fcapture-tdd -R onlyPath
    check "저장 경로 생성 실패 → exit 1" rc_is 1
    check "저장 경로 생성 실패 → 사유 stderr" stderr_has "저장 경로 생성 실패"
    check "저장 경로 생성 실패 → stdout 비어 있음" stdout_empty

    run -t region_static -p "$WORK/out-static" -R onlyPath
    check "region_static·staticRegion 없음 → exit 1" rc_is 1
    check "region_static·staticRegion 없음 → 사유 stderr" stderr_has "staticRegion"
    check "region_static·staticRegion 없음 → stdout 비어 있음" stdout_empty
    finish failure-exit-code-nonzero
}

# 4. %id 가 3자리 제로패딩으로 치환 (격리 HOME 이라 카운터가 001 부터)
t_filename_id_zeropad() {
    begin filename-id-zeropad
    local dir="$WORK/out-id"
    run -t "$SCREEN_TARGET" -p "$dir" -F "tdd_%id" -R onlyPath
    check "1회차 exit 0" rc_is 0
    check "1회차 파일명 tdd_001.png" [ "$(basename "$(cat "$OUT")")" == "tdd_001.png" ]
    check "1회차 파일 존재" [ -f "$dir/tdd_001.png" ]
    run -t "$SCREEN_TARGET" -p "$dir" -F "tdd_%id" -R onlyPath
    check "2회차 파일명 tdd_002.png" [ "$(basename "$(cat "$OUT")")" == "tdd_002.png" ]
    finish filename-id-zeropad
}

# 5. companion YAML 8종 후보를 모두 인식
#    참조 {dir/t4.basePath.txt} 가 없을 때 baseName(t4.basePath)·firstPart(t4) × 4확장자를 찾는다
t_companion_yaml_lookup() {
    begin companion-yaml-lookup
    local n=0
    for stem in t4.basePath t4; do
        for ext in default.yaml default.yml yaml yml; do
            n=$((n + 1))
            local dir="$WORK/companion/$n"
            local cand="$stem.$ext"
            mkdir -p "$dir"
            echo "capturePath: $dir/out" >"$dir/$cand"
            cat >"$dir/config.json" <<EOF
{"target": "$SCREEN_TARGET", "capturePath": "{$dir/t4.basePath.txt}", "fileFormat": "cy", "result": "onlyPath"}
EOF
            run "$dir/config.json"
            check "$cand → exit 0" rc_is 0
            check "$cand → capturePath 적용 ($dir/out/cy.png)" [ "$(cat "$OUT")" == "$dir/out/cy.png" ]
        done
    done
    finish companion-yaml-lookup
}

# 8. -t window_pointer --result onlyPath → 파일 경로 1줄만 stdout, 파일 존재
t_window_pointer_onlypath() {
    begin window-pointer-onlypath
    local helper="$WORK/pointer-to-front-window"
    if ! swiftc -O -o "$helper" "$ROOT/tdd/pointer-to-front-window.swift" 2>"$WORK/helper.err"; then
        RC=-1; OUT="$WORK/helper.err"; ERR="$WORK/helper.err"
        check "헬퍼 컴파일" false
        finish window-pointer-onlypath
        return
    fi
    local moved
    moved="$("$helper")" || true
    echo "    · 포인터 이동: ${moved:-없음}"
    run -t window_pointer -R onlyPath --no-flash -p "$WORK/out-wp"
    check "exit 0" rc_is 0
    check "stdout 정확히 1줄" stdout_lines 1
    check "stdout 경로의 파일 존재" [ -f "$(cat "$OUT")" ]
    finish window-pointer-onlypath
}

# 9. --relay N / config relay → 캡처가 N초 지연
t_relay_delay() {
    begin relay-delay
    local t0 t1 file
    t0=$(now)
    run --relay 2 -t "$SCREEN_TARGET" -p "$WORK/out-relay-cli" -R onlyPath
    t1=$(now)
    file="$(cat "$OUT")"
    check "--relay 2 → exit 0" rc_is 0
    check "--relay 2 → 경과 ≥ 2초 ($(perl -e "printf '%.2f', $t1-$t0")s)" perl -e "exit(($t1-$t0) >= 2 ? 0 : 1)"
    check "--relay 2 → 파일 mtime 이 시작 + 2초 이후" perl -e "exit(((stat('$file'))[9] - int($t0)) >= 2 ? 0 : 1)"

    cat >"$WORK/relay.json" <<EOF
{"target": "$SCREEN_TARGET", "capturePath": "$WORK/out-relay-cfg", "result": "onlyPath", "relay": 2}
EOF
    t0=$(now)
    run "$WORK/relay.json"
    t1=$(now)
    check "config relay 2 → exit 0" rc_is 0
    check "config relay 2 → 경과 ≥ 2초 ($(perl -e "printf '%.2f', $t1-$t0")s)" perl -e "exit(($t1-$t0) >= 2 ? 0 : 1)"
    finish relay-delay
}

# 10. capturePath 배열 인덱스가 가리키는 폴더가 없으면 만들어 거기 저장 (바탕화면 폴백 금지)
t_path_array_dir_create() {
    begin path-array-dir-create
    local dir="$WORK/out-array/sub"
    cat >"$WORK/array.json" <<EOF
{"target": "$SCREEN_TARGET", "capturePath": 0, "capturePathArray": ["$dir"], "fileFormat": "arr", "result": "onlyPath"}
EOF
    run "$WORK/array.json"
    check "exit 0" rc_is 0
    check "stdout 이 배열 경로 ($dir/arr.png)" [ "$(cat "$OUT")" == "$dir/arr.png" ]
    check "파일 존재" [ -f "$dir/arr.png" ]
    finish path-array-dir-create
}

# 11. 공식 빌드만 Official Build 구성요소(resources/official/)를 담는다 — 소스 빌드는 담지 않는다 (Issue30)
#     공식 빌드는 deploy-brew.sh --build-only 산출물(universal2 · gh·Formula·소스 무접촉 — 이 목표만 빌드가 돈다).
#     반복 실행은 FCAPTURE_OFFICIAL_BIN=<이미 만든 공식 빌드> 로 빌드를 건너뛴다
t_official_build_marker() {
    begin official-build-marker
    local expected="fCapture $(tr -d '[:space:]' <"$VERSION_FILE")"

    run --version
    check "소스 빌드 --version → 'Official Build' 표기 없음" stdout_lacks "Official Build"
    check "소스 빌드 → 배너 섹션 없음" lacks_section "$BIN" __fc_banner
    check "소스 빌드 → 아이콘 섹션 없음" lacks_section "$BIN" __fc_icon

    local official="${FCAPTURE_OFFICIAL_BIN:-}"
    if [[ -z "$official" ]]; then
        official="$(HOME="$REAL_HOME" CFFIXED_USER_HOME="$REAL_HOME" "$ROOT/deploy-brew.sh" --build-only 2>"$WORK/official-build.err" | tail -n 1)"
    fi
    check "공식 빌드 산출 ($official)" [ -x "$official" ]
    [[ -x "$official" ]] || tail -n 5 "$WORK/official-build.err" | sed 's/^/       build: /'

    local source_bin="$BIN"
    BIN="$official"
    run --version
    BIN="$source_bin"
    check "공식 빌드 --version 1줄째 = '$expected'" [ "$(head -n 1 "$OUT")" == "$expected" ]
    check "공식 빌드 --version → 'Finfra Official Build' 표기" stdout_has "Finfra Official Build"
    check "공식 빌드 → 배너 섹션 포함" has_section "$official" __fc_banner
    check "공식 빌드 → 아이콘 섹션 포함" has_section "$official" __fc_icon
    finish official-build-marker
}

ALL_IDS=(version-flag invalid-target-exit1 failure-exit-code-nonzero filename-id-zeropad companion-yaml-lookup window-pointer-onlypath relay-delay path-array-dir-create official-build-marker)
IDS=("$@")
[[ ${#IDS[@]} -eq 0 ]] && IDS=("${ALL_IDS[@]}")

echo "🧪 fCapture TDD — bin=$BIN work=$WORK"
for id in "${IDS[@]}"; do
    fn="t_${id//-/_}"
    if ! declare -F "$fn" >/dev/null; then
        echo "❌ 알 수 없는 목표 id: $id" >&2
        exit 1
    fi
    "$fn"
done

echo "=================================="
echo "결과: PASS $PASS / FAIL $FAIL"
if [[ $FAIL -gt 0 ]]; then
    echo "실패 목표: ${FAILED_IDS[*]}"
    exit 1
fi
rm -rf "$WORK"
exit 0

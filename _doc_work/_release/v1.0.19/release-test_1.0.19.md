---
version: 1.0.19
commit: 14f5ac7d81b4eeac18622e43f728f88e750eedc1
dirty: yes
result: partial
env: jm4
date: 2026.10.27
---

# 요약

* 변경: 지정 화면 이외 전체 화면 백업(`ee0bc2d`) + VERSION·appVersion 1.0.19(`14f5ac7`)
* 실행 머신은 jm4 — 표준 환경 jma 는 미실행이라 `partial`. dirty 는 `.vscode/settings.json`(비코드)·untracked `.agents/`·`.codex/` 때문
* 릴리즈: https://github.com/Finfra/fCapture/releases/tag/v1.0.19 · tap `Finfra/homebrew-tap@0097cb5`

| # | id | 결과 | 비고 |
| :- | :- | :- | :- |
| 1 | `dev-playlist-green` | partial | `tdd-test.sh` 9/9 pass. `captureTest.sh` Test 1~3 pass, Test 4 fail — 로컬 gitignore 파일 `bin/.fCapture.json`(2026-06-24, `target: active` 무효값) 때문이며 코드 무관. Test 5 는 스크립트가 Test 4 에서 중단되어 예제 3종(00·01·02)을 수동 실행 → 3건 저장 성공 |
| 2 | `release-package-dry-run` | pass | `deploy-brew.sh --dry-run` exit 0, universal2(x86_64+arm64) 확인 |
| 3 | `formula-sha-version-match` | pass | Formula `version` 1.0.19 · url 태그 v1.0.19 · sha256 `d137a47a…`, brew 가 해당 에셋으로 설치 |
| 4 | `brew-install-version` | pass(jm4) | `brew upgrade finfra/tap/fcapture` → `fcapture --version` = `fCapture 1.0.19` + Official Build 2줄, `brew test fcapture` rc 0. jma 미실행 |
| 5 | `brew-capture-one` | pass(jm4) | `fcapture -t window_pointer --result onlyPath` → 경로 1줄 출력(`~/Desktop/20261027_203722.png`). 신규 백업 동작도 실측: screen1 메인 + `backup_…_screen2·3·4` 3장 |
| 6 | `bin-symlink-same-build` | pass | `~/.bin/fCapture` → `/opt/homebrew/bin/fcapture`, `--version` 1.0.19 |

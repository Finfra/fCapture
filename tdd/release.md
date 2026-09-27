---
title: fCapture 배포 재생목록
description: prj51 fCapture 의 Homebrew tap(Finfra/homebrew-tap) 출고와 ~/.bin/fCapture 설치 경로 검증 목록 (prj3#Issue717)
date: 2026.09.27
gate: pre-tag
env: jma
---

# 무엇을 지키나

`brew install finfra/tap/fcapture` 로 받은 universal2 바이너리가 깨끗한 머신에서 설치·기동되고 캡처 1건을 저장하며, `~/.bin/fCapture` 경로(brew 심링크)로도 같은 판이 불리는지 지킨다

* 브랜치 모델: `develop`·`main` + 태그 `v{VER}`(GitHub Release 에셋). `release/*` 없음 → R1 은 태그 대상 커밋
* 출고 순서: `deploy-brew.sh`(빌드·tarball·sha256·`gh release create`·로컬 Formula 갱신) → tap repo Formula push(수동). R2 는 `gh release create` 직전이다
* 화면 녹화 권한이 필요한 행(#4~#6)은 GUI 세션(jma 는 GUI tmux 경유)에서 돈다

# 재생목록

| #   | id                          | 채널     | 목표                                                                                                                                             | 근거                                                                           | 실행                                   | 상태      |
| :-- | :-------------------------- | :------- | :----------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------- | :------------------------------------- | :-------- |
| 1   | `dev-playlist-green`        | —        | 개발 재생목록(`tdd/playlist.md`) 전 행 통과                                                                                                      | `tdd/playlist.md`                                                              | `./tdd/tdd-test.sh ; ./captureTest.sh` | ⬜ 미실행 |
| 2   | `release-package-dry-run`   | brew     | `deploy-brew.sh --dry-run` 이 exit 0 — universal2 빌드·tarball·sha256 산출까지 성공하고 tarball 안에 `fcapture` 1개가 있다                       | `deploy-brew.sh` 헤더 · `_doc_arch/brew-deploy-design.md` 릴리즈 절차          | `./deploy-brew.sh --dry-run`           | ⬜ 미실행 |
| 3   | `formula-sha-version-match` | brew     | `Formula/fcapture.rb` 의 `version`·`url` 태그 = `VERSION`, `sha256` = 업로드한 tarball 의 sha256                                                 | `Formula/fcapture.rb` · `brew-deploy-design.md` 79행(tap 이 SSOT, 로컬은 사본) | —                                      | ⬜ 신규   |
| 4   | `brew-install-version`      | brew     | jma 에서 `brew update && brew upgrade fcapture`(미설치면 `install`) 후 `fcapture --version` 이 `VERSION` 값을 출력하고 `brew test fcapture` 통과 | `brew-deploy-design.md` 57·151~152행 · `Formula/fcapture.rb` `test do`         | —                                      | ⬜ 신규   |
| 5   | `brew-capture-one`          | brew     | brew 설치본으로 `fcapture -t window_pointer --result onlyPath` 가 경로 1줄을 출력하고 그 파일이 존재하며 exit 0 이다                             | `tdd/playlist.md` #8 · Issue27 KM 매크로 권장 명령                             | —                                      | ⬜ 신규   |
| 6   | `bin-symlink-same-build`    | `~/.bin` | `~/.bin/fCapture` 가 brew `fcapture` 를 가리키고 `~/.bin/fCapture --version` 이 #4 와 같은 버전을 낸다                                           | `~/_git/___common/_doc_arch/bin-asset-inventory.md` 78행 (prj5 관리)           | —                                      | ⬜ 신규   |

# 증거

* 경로: `_doc_work/_release/v{VER}/release-test_{VER}.md` (`VER` = 루트 `VERSION`)
* frontmatter `version·commit·dirty·result·env·date` + `| # | id | 결과 | 비고 |` 표 — 형식 SSOT 는 `~/.claude/_doc_arch/rules-ondemand/release-test-rules.md` "증거 형식"

# 규약

* 각 행의 목표는 **검증 가능한 성질**이다 — *"잘 설치된다"* 가 아니라 버전 문자열·종료 코드·파일 존재로 판정한다
* 행을 건너뛴 실행(ex) 권한 없는 세션에서 #5 생략)은 `result: partial` 로 기록한다 — `pass` 로 쓰지 않는다
* 실패를 삼키지 않는다(`2>/dev/null || true` 금지) — 실패는 실패로 증거에 남긴다

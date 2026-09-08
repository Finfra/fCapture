---
title: brew 배포 재검증 결과 (Issue26_3)
description: 설치 명령 표기 대조·sha256 무결성·깨끗한 환경 재설치 실측 로그
date: 2026.09.09
---

# 요약

방문자가 홈페이지의 설치 명령을 그대로 복사해 성공하는지 실측했다. **설치 경로는 정상 동작한다.** 다만 게재 전에 결정이 필요한 사항이 하나 남는다 — 새 릴리스를 낼지 여부다.

# 표기 불일치 — 이미 해소되어 있음

Issue26_3 은 GitHub 저장소 설명이 `brew install finfra/tap/fc` 로 되어 있어 README·Formula 의 `fcapture` 와 어긋난다고 기록했다. **실측 결과 이 불일치는 존재하지 않는다.**

| 위치 | 실측값 |
| :--- | :--- |
| GitHub 저장소 설명 | `... brew install finfra/tap/fcapture` |
| [README.md](README.md) 20행 | `brew install finfra/tap/fcapture` |
| tap `Formula/fcapture.rb` | `class Fcapture`, 설치물 `bin.install "fcapture"` |

`tap/fc` 표기는 추적 대상 문서 어디에도 남아 있지 않다(전수 grep 0건). 이슈 등록 시점의 관측이 낡았거나 그 사이 수정된 것으로 보인다. **따라서 표기를 고치는 작업은 수행하지 않았다** — 고칠 대상이 없다.

짧은 별칭 `fc` 를 tap alias 로 둘지는 별도 결정 사항이다. 현재 tap 에 `Aliases/` 디렉토리는 없다. 별칭이 없어도 설치는 성공하므로 게재를 막는 요소는 아니다 🚧

# sha256 무결성

릴리스 tarball 을 내려받아 Formula 기재값과 대조했다. **일치한다.**

```
url    https://github.com/Finfra/fCapture/releases/download/v1.0.18/fCapture-1.0.18.tar.gz
실제   4fbba5c9c834838db2b230c7781bd698536fc2e35729ecd05fc271dfb9745cde
Formula 4fbba5c9c834838db2b230c7781bd698536fc2e35729ecd05fc271dfb9745cde
```

# 깨끗한 환경 재설치

`brew uninstall` 후 tap 에서 새로 설치하는 전 과정을 실행했다.

```
$ brew uninstall fcapture
Uninstalling /opt/homebrew/Cellar/fcapture/1.0.18... (3 files, 1MB)

$ which fcapture
fcapture not found

$ brew install finfra/tap/fcapture
==> Fetching downloads for: fcapture
✔︎ Formula fcapture (1.0.18)
==> Installing fcapture from finfra/tap
🍺  /opt/homebrew/Cellar/fcapture/1.0.18: 4 files, 1MB, built in 1 second

$ fcapture --version
fCapture 1.0.18                      # exit 0

$ fcapture -t screen:1 -R onlyPath -p /tmp/fcap_brew
/tmp/fcap_brew/20260909_002813.png   # exit 0, 파일 968K 생성 확인
```

| 검증 항목 | 결과 |
| :--- | :--- |
| 제거 후 명령 사라짐 | ✅ |
| tap 에서 재설치 | ✅ |
| `fcapture --version` → `1.0.18` | ✅ |
| 실제 캡처 동작 | ✅ 파일 생성 확인 |
| caveats(권한 안내) 노출 | ✅ |
| `~/.bin/fCapture` symlink 무결성 | ✅ `-> /opt/homebrew/bin/fcapture`, 대문자 별칭도 동작 |

symlink 는 재설치 후에도 끊기지 않았다. brew 가 같은 경로에 다시 설치하기 때문이다.

# 결정 대기 — 새 릴리스를 낼 것인가

**낼 것을 권장한다.** 근거는 하나다.

Issue26_1 에서 CLI 종료 코드 규약을 고쳤다(`fe68bf5`). MCP 서버는 이 종료 코드로 성공/실패를 판정하는데, **brew 배포본 v1.0.18 은 이 수정 이전 바이너리라 실패해도 0 을 반환한다.** MCP 서버를 prj20 에 배치해도 배포본이 그대로면 조용한 실패가 그대로 남는다.

`v1.0.18` 이후 코드 변경은 실질적으로 이 한 건이며(나머지는 문서·설정), 릴리스 절차는 [brew-deploy-design.md](_doc_arch/brew-deploy-design.md) 와 [deploy-brew.sh](deploy-brew.sh) 에 이미 정리되어 있다.

**단, 릴리스는 GitHub release 생성과 tap 저장소 커밋을 수반하는 외부 시스템 쓰기라 본 위임 세션의 범위 밖이다.** 사용자 승인 후 별도로 진행해야 한다.

# prj10 에 전달할 사항

라이선스는 **PolyForm Noncommercial 1.0.0** 이다. 홈페이지 문구를 "오픈소스" 로 적으면 사실과 다르다. **"비상업 무료 · 상업 별도 라이선스"** 로 표기해야 한다.

GitHub 의 라이선스 인식도 `Other` 로 잡혀 있어(SPDX 표준 목록 밖) 저장소 배지만 보고 판단할 수 없다. 문구는 수동으로 맞춰야 한다.

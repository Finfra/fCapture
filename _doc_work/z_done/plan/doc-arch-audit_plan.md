---
name: doc-arch-audit_plan
description: _doc_arch 영속 설계 문서와 소스코드 정합성 감사 — 참조 경로·심볼명·동작 서술·폐기 설계 4축 전수 검토 및 교정 계획
date: 2026-07-20
issue: Issue23
arch: _doc_arch/brew-deploy-design.md
---

# 배경

prj1#Issue307 fan-out 의 일부. 방법론 원본은 prj1#Issue306.

`_doc_arch/` 는 이슈 종결 후에도 유지되는 영속 설계 SSOT 다. 그러나 소스코드는 이슈를 거치며 계속 변하므로, 문서가 참조하는 파일 경로·함수명·라인 번호·동작 서술이 시간이 지나면 조용히 stale 해진다. stale 한 SSOT 는 없는 것보다 나쁘다 — 후속 작업자가 그것을 근거로 잘못된 판단을 내리기 때문이다.

본 계획은 fCapture 의 `_doc_arch/` 문서 3종을 현재 소스코드와 전수 대조하여 어긋난 곳을 찾아 교정하는 절차를 정의한다.

# 감사 대상

`_doc_arch/` 하위 마크다운 3종. `z_done/`·`img/` 는 대상 제외이며, 현재 프로젝트에는 `define/`·`z_old/` 빈 폴더만 존재하므로 실제 대상은 아래가 전부다.

| 문서                       | 성격                                   |
| :------------------------- | :------------------------------------- |
| `brew-deploy-design.md`    | Homebrew 배포 설계 SSOT (Issue22 산출) |
| `yaml-companion-config.md` | companion YAML 참조 메커니즘 SSOT      |
| `Glossary.md`              | 캡처 모드·옵션 용어 사전               |

# 검증 축 4종

| 축  | 내용                             | 방법                                              |
| :-- | :------------------------------- | :------------------------------------------------ |
| (1) | 참조 경로 실존 여부              | 문서 내 모든 경로를 `ls`·`Glob` 으로 실존 확인    |
| (2) | 스크립트·함수·상수명 일치        | `grep -n` 으로 심볼 실존 + 라인 번호 대조         |
| (3) | 핵심 동작 서술과 실제 로직 일치  | 해당 함수 본문을 읽어 문서 서술과 1:1 비교        |
| (4) | 폐기된 설계 잔존 여부            | 완료된 이슈의 "미충족·예정" 표현이 남았는지 확인  |

# Needs Exploration

탐색 결과 불일치 12건을 식별했다. 축별 분류는 아래와 같다.

## brew-deploy-design.md

| ID  | 위치                                  | 축  | 판정                                                                              |
| :-- | :------------------------------------ | :-: | :-------------------------------------------------------------------------------- |
| B1  | L28~35 `# 선결 조건 (현재 미충족)`    | (4) | **stale** — `origin` remote(`Finfra/fCapture`)·`VERSION`(1.0.18) 둘 다 실존. 해소됨 |
| B2  | L10 개요 "외부 사용자 설치 경로 없음" | (4) | **stale** — brew 배포가 이미 완료(Issue22)되어 전제가 뒤집힘                        |
| B3  | L75 헤딩 `Formula 설계 (source-build)`| (4) | **stale** — 실제 채택은 pre-built binary. 헤딩만 구안(舊案) 잔존                    |
| B4  | L85 `sha256 "<release tarball sha256>"`| (3) | **stale** — 실제 Formula 는 `4fbba5c9c8…` 확정값 보유                              |
| B5  | L34 `ScreenCaptureApp.swift:420`      | (2) | ✅ 정확 — `static let appVersion = "1.0.18"` 실제 L420                             |
| B6  | L108 `ScreenCaptureApp.swift:858,887,922,960` | (2) | ✅ 정확 — `Bundle.main` 접근 4곳 라인 전부 일치                              |
| B7  | L22~26 참조 경로 5종                  | (1) | ✅ 전부 실존                                                                       |
| B8  | L117 `buildAndTest.sh` sed 주입 서술  | (3) | ✅ 정확 — `buildAndTest.sh:44~47` 에 VERSION → appVersion sed 구현                  |
| B9  | L148 🚧 `bin/deploy-brew.sh` 자동화   | (1) | ✅ 유효한 TODO — 파일 미존재 확인, 마커 유지                                        |

## yaml-companion-config.md

| ID  | 위치                          | 축  | 판정                                                                                       |
| :-- | :---------------------------- | :-: | :----------------------------------------------------------------------------------------- |
| Y1  | 참조 함수 9종                 | (2) | ✅ 전부 실존 (`resolveRawConfigReferences:1834` 등)                                         |
| Y2  | L98~99 companion 탐색 순서    | (3) | **불일치** — 문서는 "baseName 3종 전부 → firstPart 3종"이나 실제는 확장자가 바깥 루프        |
| Y3  | L101 `t4.basePath.txt → t4.default.yml 자동 연결` | (3) | **거짓** — 탐색 확장자 목록에 `default.yml` 이 없어 해당 연결은 성립 불가 |
| Y4  | L23~26 파일 경로 4종          | (1) | ✅ 실존 — `t4.default.yml`·symlink·`jm4_*.json` 모두 확인                                    |
| Y5  | L107 `relay: Double?`         | (2) | ✅ 정확 — `ScreenCaptureApp.swift:265`                                                      |

Y3 은 문서만의 오기가 아니라 **코드 결함의 노출**이다. `findCompanionYAML` 의 확장자 목록이 `["default.yaml", "yaml", "yml"]` 이라 `{baseName}.default.yml` 조합이 만들어지지 않는데, 정작 실제 운영 파일은 `t4.default.yml`(`.yml`) 이다.

## Glossary.md

| ID  | 위치                       | 축  | 판정                                                                                         |
| :-- | :------------------------- | :-: | :------------------------------------------------------------------------------------------- |
| G1  | 참조 함수 4종              | (2) | ✅ 실존 (`TargetType:351`·`parseTargetType:750`·`captureSingleImage:1281`·`printHelp:959`)     |
| G2  | L34~39 alias 표            | (3) | **부정확** — `window`·`region` alias 는 CLI 경로 전용이며 JSON decoder 는 `.single()` 로 처리 |
| G3  | L96 `버전 출력 (현재 1.0.18)` | (3) | 하드코딩 — VERSION 파일 참조 표현으로 바꿔 재발 차단                                       |
| G4  | L85 `~/Desktop` 일치 서술  | (3) | ✅ 정확 — 코드 fallback `ScreenCaptureApp.swift:2003` 이 `~/Desktop`                          |
| G5  | L57 `windowFlash ?? true`  | (3) | ✅ 정확 — `:1336`·`:1363`                                                                     |
| G6  | L94 프리셋 `-r`            | (3) | ✅ 정확 — `parseArguments:461` 이 `-r` 만 인식                                                 |

# 부수 발견 (코드측 결함)

문서 감사 과정에서 드러난 소스코드 자체의 결함이다. 본 이슈 범위는 문서 교정이므로 코드를 고치지 않고, 문서에 `🔧 [FIXME]` 마커로 남겨 후속 이슈 후보로 보존한다.

| 항목                                                        | 영향                                             |
| :---------------------------------------------------------- | :----------------------------------------------- |
| `findCompanionYAML` 확장자 목록에 `default.yml` 누락         | `.yml` 기본 템플릿으로의 companion fallback 미작동 |
| `printHelp` fallback 이 `--no-flash` 를 기본값이라 표기      | 실제 기본은 flash ON(`?? true`) — help 오기        |
| 번들 `Usage.txt` 가 `-r, --region` 을 프리셋으로 병기        | `--region` 은 좌표 옵션이며 프리셋으로 인식 안 됨  |
| `ScreenCaptureApp.swift:801` `case "-r", "--region":`        | `--region` 분기는 도달 불가(dead branch)          |

# 교정 방침

* **stale 서술은 현재 상태로 갱신**한다. 과거 결정 이력은 지우지 않고 "초기 설계는 A 였으나 변경" 형태의 기존 서술을 유지한다 — 설계 문서의 가치는 결정의 흔적에 있다.
* **해소된 TODO 는 마커를 떼고 결과를 반영**한다. 미해소 TODO(B9)는 마커를 유지한다.
* **동작 서술 불일치(Y2·Y3·G2)는 실제 코드 로직대로 다시 쓴다.** 코드가 틀린 경우(Y3)는 문서를 코드 현실에 맞추되 `🔧 [FIXME]` 로 결함임을 명시한다.
* **버전 등 변동값 하드코딩은 참조 표현으로 치환**해 같은 종류의 stale 재발을 줄인다.

# 검증

교정 후 아래를 재실행하여 잔존 stale 이 없음을 확인한다.

1. 문서 내 모든 파일 경로를 다시 수집해 `ls` 로 실존 확인 (축 1)
2. 인용된 `파일:라인` 을 `sed -n` 으로 열어 심볼 일치 확인 (축 2)
3. `grep` 으로 `미충족`·`source-build`·`<release tarball sha256>` 등 폐기 표현 잔존 0건 확인 (축 4)

# 관련 자료

* 이슈: [Issue.md](../../Issue.md) Issue23
* task: [doc-arch-audit_task.md](../tasks/doc-arch-audit_task.md)
* 방법론 원본: prj1#Issue306 / fan-out: prj1#Issue307

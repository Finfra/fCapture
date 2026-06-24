---
name: doc-arch-sync_report
description: fCapture _doc_arch 설계 문서 ↔ 소스코드 정합성 동기화 결과
date: 2026-06-15
---

# 요약

prj51 fCapture `_doc_arch/` 2개 문서를 Swift 소스(`fCapture/*.swift`)와 대조함.

* `Glossary.md` — **대폭 stale**. target 값 목록이 구 표기(`window`/`region`/`staticRegion`)에 머물러 있고, canonical `_` 접미 명칭(`window_pointer`/`window_active`/`window_flash`/`region_user`/`region_static`)과 `scroll_capture`·`relay`·`window_flash`·`result` 용어 누락. → 코드 기준 전면 재작성.
* `yaml-companion-config.md` — **메커니즘은 정합**. 치환 규칙·companion 탐색 순서·relay 우선순위 모두 코드와 일치. → 번들 기본 템플릿 파일명(`default.yml`) 명시 보강만 수행(소폭).

# 조사 범위

* 소스: `fCapture/ScreenCaptureApp.swift`(2134줄, 핵심), `ScreenCapture.swift`, `ScrollCapture.swift`, `default.yml`(번들 템플릿)
* 대조 지점:
    - `TargetType.init(from:)` (351~398), `parseTargetType` (750~774), `captureSingleImage` target 분기 (1281~1375)
    - `printHelp` Usage 텍스트 (959~1018)
    - `resolveRawConfigReferences` (1834~1979), `findCompanionYAML` (1785~1810), `parseSimpleYAML`/`parseYAMLArrays` (1692~1758)
    - `ScreenCaptureConfig` 구조체·CodingKeys (254~399), `mergeConfig` (649~747), `main` relay 적용 (831)
    - 번들 `default.yml`
* git log(`ScreenCaptureApp.swift`)·`Issue.md` 로 명칭 진화 맥락 확인(Issue8 window 분화, Issue17~19 scroll, Issue20~21 relay).

# 핵심 불일치

| # | 분류 | 위치 | 내용 |
| - | ---- | ---- | ---- |
| 1 | (c) 세부값 오류 | Glossary target 표 | `window`→canonical `window_pointer`; `region`→`region_user`; `staticRegion`→`region_static`. 코드는 `_` 접미가 canonical, 구 표기는 alias |
| 2 | (b) 코드엔 있으나 문서에 없음 | Glossary | `window_active`, `window_flash`(별도 target), `scroll_capture` 모드 전체 누락 |
| 3 | (b) 코드엔 있으나 문서에 없음 | Glossary | `relay`(지연), `window_flash`(플래시 옵션), `result`(text/json/onlyPath), `fileFormat` 토큰, `capturePath` 인덱스 용어 누락 |
| 4 | (a) 문서 이력이 stale | Glossary "active → window (2026-03-27)" | 그 후 Issue8 에서 `window_pointer`/`window_active`/`window_flash` 로 재분화됨 — 이력이 현재 상태를 오도 |
| 5 | (c) 보조 부정확 | (help 텍스트 자체) | `-p` help 가 "기본값 ~/Pictures" 라 적었으나 실제 fallback 은 `~/Desktop`(`determineSavePath` `.desktopDirectory`). Glossary 에 실제값(Desktop) 명기 |
| 6 | (b) 보강 | yaml-companion-config | 번들 자동 생성 템플릿이 `default.yml` 임이 미기재(본문은 jm4 인스턴스 `t4.default.yml` 만 예시) |

# 동기화 결과

## Glossary.md (전면 재작성)
* canonical target 8종 표 + alias 매핑 표(window/staticRegion/region/scroll) 분리 기재.
* 옵션 용어 섹션 신설: shadow / window_flash / relay / result / fileFormat / capturePath.
* 프리셋 플래그 표(-s/-w/-r/-f/-h/-v) 추가.
* 변경 이력을 코드 진화(window 분화·region 명칭·scroll·relay)에 맞게 재작성.
* 기본값 정정: target 미지정=`window_pointer`, 저장 fallback=`~/Desktop`.
* 상단 개정일·사유, frontmatter `date: 2026-06-15`.

## yaml-companion-config.md (소폭 보강, 무변경 아님)
* 메커니즘 본문은 코드와 정합 → 유지.
* "파일 관계" 섹션에 번들 기본 템플릿(`default.yml` + JSON 4종) 자동 생성 경로 note 추가. `t4.default.yml` 이 jm4 인스턴스 예시임을 명시.
* 상단 개정일·사유, frontmatter `date: 2026-06-15`.

# 검증

* target canonical/alias: `TargetType.init`(363~377) + `parseTargetType`(752~772) + `captureSingleImage`(1325~1375) 3곳 교차 확인 — bare `window`/`region` 은 `.single` 로 떨어진 뒤 `captureSingleImage` 에서 동일 처리됨을 확인.
* relay 우선순위 `overrides.relay ?? config.relay`(831) ↔ 문서 "CLI > 설정파일" 일치.
* companion 탐색 순서: 코드 `["default.yaml","yaml","yml"]` × (full baseName→firstPart)(1793~1808) ↔ 문서 2-tier 기술 일치.
* 치환 표(screen:{ref}→screen:N, number=-1→all, capturePath Int/String, relay Double, capturePathArray 배열) 전부 `resolveRawConfigReferences` 대조 일치.
* 번들 `default.yml` 의 nested `target: name/number` 구조가 `parseSimpleYAML`(flat) 로 정상 파싱됨(들여쓰기 strip → `name`/`number` top-level key) 확인.

# 미해결

* **코드측 help 텍스트 버그(문서 아님)**: `printHelp` 의 `-p` 기본값 안내가 `~/Pictures` 로 실제 동작(`~/Desktop`)과 불일치. 본 작업은 _doc_arch 동기화 범위이므로 소스 미수정. 별도 이슈로 `Usage.txt`/`printHelp` 정정 권장.
* fCapture 에 `Issue.md` 가 있으나 본 작업은 문서 정합 한정 — 위 help 버그 이슈 등록은 사용자 판단에 위임.

# 변경 파일

* `_doc_arch/Glossary.md` (전면 재작성)
* `_doc_arch/yaml-companion-config.md` (frontmatter date + 개정 note + 번들 템플릿 보강)
* `_doc_work/report/doc-arch-sync_report.md` (본 리포트, 신규)

(커밋 없음 — 작업 제약)

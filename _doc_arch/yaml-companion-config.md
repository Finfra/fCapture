---
name: yaml-companion-config
description: fCapture companion YAML 설정 구조 — JSON이 {경로} 패턴으로 YAML 값을 참조하는 메커니즘 SSOT
date: 2026-06-15
---

> 개정 (2026-06-15): 코드(`ScreenCaptureApp.swift` resolveRawConfigReferences·findCompanionYAML·parseSimpleYAML·parseYAMLArrays) 대조 결과 본 문서의 메커니즘 기술은 정합함. 번들이 실제 자동 생성하는 기본 템플릿 파일명(`default.yml`)을 명시 보강함(기존 본문의 `t4.default.yml` 은 jm4 머신 인스턴스 예시).

# 개요

fCapture는 설정을 **JSON 파일**로 받지만(`loadConfig`는 JSON 전용), 실제 값은 **companion YAML** 파일에 모아 두고 JSON이 `{경로}` 패턴으로 참조하도록 설계되었다. 이 문서는 그 구조와 해석 흐름의 단일 출처(SSOT)다.

핵심 제약: **YAML 파일을 fCapture에 직접 인자로 줄 수 없다.** `fCapture some.yml` 은 `JSON text did not start with array or object` 오류로 실패한다. YAML은 JSON 안에서 `{경로}` 참조로만 동작한다.

# 파일 관계

머신별 설정(jm4, jma 등)은 YAML 한 개를 값 저장소로 두고, 여러 JSON 래퍼가 같은 YAML을 참조하되 캡처 대상(target)만 달리한다.

> **번들 기본 템플릿**: 앱 첫 실행 시 `initializeConfigFiles → createBundleYAMLIfNeeded(fileName: "default")` 가 번들의 `default.yml` 을 `~/.fCapture/default.yml` 로 복사한다. JSON 4종(`defaultSetting`/`defaultScreen`/`defaultRegion`/`defaultWindow`)도 동일하게 자동 생성된다. 아래 `t4.default.yml` 표기는 jm4 머신용 개인 인스턴스 예시이며, 구조는 번들 `default.yml` 과 동일하다.

| 파일 | 역할 |
| :--- | :--- |
| `~/.fCapture/jm4/t4.default.yml` | 값 저장소(SSOT) — capturePath, target, fileFormat, flash, shadow, relay 등 |
| `~/_doc/1.Area/_memo/t4.default_jm4.yml` | 편집 편의용 심볼릭 링크 → 위 실제 파일 |
| `~/.fCapture/jm4/jm4_Screen.json` | 화면 캡처 진입 JSON — 필드를 `{...t4.default.yml}` 로 참조 |
| `~/.fCapture/jm4/jm4_Window/Region/Scroll.json` | 같은 YAML 참조, target 종류만 다른 래퍼 |

## YAML 예시 (t4.default.yml)

```yaml
capturePath: 0
capturePathArray:
  - "~/Desktop"
  - "~/Desktop/tmp"
  - "/Users/nowage/GoogleDrive_finfra/2026x"
target:
  name: "screen"
  number: 1
fileFormat: "%d_%T_%target"
"window_flash": true
"shadow": false
relay: 3   # 캡처 N초 지연 후 실행
```

## JSON 래퍼 예시 (jm4_Screen.json)

```json
{
    "target": "screen:{~/.fCapture/jm4/t4.default.yml}",
    "capturePath": "{~/.fCapture/jm4/t4.default.yml}",
    "capturePathArray": "{~/.fCapture/jm4/t4.default.yml}",
    "fileFormat": "{~/.fCapture/jm4/t4.default.yml}",
    "window_flash": "{~/.fCapture/jm4/t4.default.yml}",
    "shadow": "{~/.fCapture/jm4/t4.default.yml}",
    "relay": "{~/.fCapture/jm4/t4.default.yml}"
}
```

# 동작 흐름

올바른 실행은 **JSON을 인자로** 주는 것이다: `fCapture ~/.fCapture/jm4/jm4_Screen.json`

```
fCapture jm4_Screen.json
  → parseArguments()        비옵션 인자 → configFile 판정
  → loadConfig(path)        JSONSerialization 으로 JSON → dict
  → resolveRawConfigReferences(&dict)
        각 필드의 {경로} 패턴 탐지
        → findCompanionYAML()   참조 경로의 실제 yml 해석
        → parseSimpleYAML / parseYAMLArrays   필드 값 추출
        → dict 값 치환 (screen:{ref}→screen:1, capturePath→0, relay→3 ...)
  → JSONDecoder            치환된 dict → ScreenCaptureConfig
  → capturePath=0          → capturePathArray[0] = ~/Desktop 저장 경로 확정
  → 지연(relay) 적용         CLI --relay > config.relay > 없음
  → performCapture(config)  실제 캡처
```

# 필드별 치환 규칙

`resolveRawConfigReferences`(ScreenCaptureApp.swift)가 디코딩 직전에 `{경로}` 를 실제 값으로 치환한다.

| JSON 원본 | YAML 값 | 최종 치환 | 처리 |
| :--- | :--- | :--- | :--- |
| `"screen:{...yml}"` | target.name=screen, number=1 | `"screen:1"` (number=-1이면 `all`) | target 특수 분기 |
| `capturePath "{...yml}"` | `0` | `0` (Int, 배열 인덱스) | Int/String 분기 |
| `capturePathArray "{...yml}"` | 리스트 | `["~/Desktop", …]` | parseYAMLArrays |
| `fileFormat "{...yml}"` | "%d_%T_%target" | 그대로 | 문자열 |
| `window_flash` / `shadow` | true / false | Bool | Bool 변환 |
| `relay "{...yml}"` | `3` | `3.0` (Double) | 숫자 변환 |

- `capturePath: 0` 은 `capturePathArray` 의 **인덱스**다. 0=`~/Desktop`, 1=`~/Desktop/tmp`, 2=GoogleDrive.
- `relay` 우선순위: **CLI `--relay` > 설정 파일 `relay`**. 둘 다 없으면 지연 없음.

# companion 파일명 탐색 규칙

`findCompanionYAML` 은 참조 경로가 존재하지 않을 때 형제 파일을 자동 탐색한다.

1. 전체 baseName: `{baseName}.default.yaml → {baseName}.yaml → {baseName}.yml`
2. 첫 컴포넌트만: `{firstPart}.default.yaml → …`

덕분에 `t4.basePath.txt` placeholder가 `t4.default.yml` 로 자동 연결될 수 있다.

# relay 설정 지원 (Issue21)

`relay` 는 원래 CLI `--relay N` 플래그(Issue20)로만 지정 가능했으나, Issue21에서 설정 파일/companion YAML 에서도 지정 가능하도록 확장했다.

- `ScreenCaptureConfig.relay: Double?` 필드 추가
- `resolveRawConfigReferences` 에 `relay` companion 참조 해석 추가 (YAML 문자열 → Double)
- `main()`: `overrides.relay ?? config.relay` 로 적용 (CLI 우선)

# 설계 결정 요약

- YAML은 값의 SSOT, JSON은 캡처 모드를 선택하는 얇은 래퍼다.
- 머신별(jm4/jma) YAML 분리로 동일 JSON 구조를 여러 환경에서 재사용한다.
- 신규 설정 필드 추가 시: ① Config 구조체 필드 + CodingKey, ② 필요 시 `resolveRawConfigReferences` companion 해석, ③ 본 문서 표 갱신.

# 변경 이력 기준

- Issue20: `--relay` CLI 옵션 추가
- Issue21: relay 설정 파일/companion YAML 지원 + 본 문서 작성

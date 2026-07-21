# ✅ 완료


## Issue2: DefaultSettingPath.txt 지원 ✅
* 목적: 파라메터 없이 실행 시 ~/.fCapture/DefaultSettingPath.txt에서 기본 설정 파일 경로 읽기
* 구현 명세:
    - loadDefaultConfigPath() 함수 추가
    - 틸드 경로 확장 지원 (~/.fCapture/ → 절대경로)
    - 우선순위: 명령줄 인수 > DefaultSettingPath.txt > .fCapture.json > 기본값

## backupOtherScreen 기능 ✅
* 목적: screen:1/screen:2 캡처 시 반대 화면도 백업 저장
* 구현 명세:
    - ScreenCaptureConfig에 backupOtherScreen: String? 필드 추가
    - shouldBackupOtherScreen(), getBackupTarget(), performBackupCapture() 함수 구현
    - screen:1 ↔ screen:2 상호 백업 (screen:3 이상은 제외)

## Issue3: json구조 추가 (commit: 661793d) ✅
* 목적: capturePath의 값이 숫자일 경우 capturePathArray에서 해당 인덱스 경로 사용
* 구현 명세:
    - CapturePathType enum 추가 (문자열/정수 지원)
    - capturePathArray 필드 분리 (JSON 키 충돌 방지)
    - determineSavePath 로직 확장 (인덱스 기반 경로 선택)
    - 에러 처리 및 폴백 기능 (잘못된 인덱스 시 Desktop 사용)

## Issue4: 파라메터 없이 실행 시 DefaultSettingPath.txt 기본 경로 설정 ✅
* 목적: 파라메터 없이 실행하면 DefaultSettingPath.txt 파일을 읽어서 해당 파일의 경로를 기본 저장 경로로 설정

## Issue5: .fCapture.json·DefaultSettingPath.txt 제거 → ~/.fCapture/defaultSetting.json 도입 (등록: 2026-03-27, 해결: 2026-03-27, commit: ffeeb03) ✅
* 목적: 설정 우선순위 단순화 및 사용자 기본 설정을 단일 파일로 관리
* 구현 명세:
    - `loadDefaultConfigPath()` 함수 제거
    - `loadOrCreateDefaultSetting()` 함수 추가 (없으면 기본값으로 자동 생성)
    - 새 우선순위: `명령줄 인수 > ~/.fCapture/defaultSetting.json > 코드 기본값`
    - `window_point` 타겟 추가 (`screencapture -w`)
    - target 용어 통일: `active` → `window`, shadow 기본값 false 명시
    - 관련 문서 전체 업데이트 (README, CLAUDE, GEMINI, AGENTS, rules)
    - `_doc_arch/Glossary.md` 신규 생성


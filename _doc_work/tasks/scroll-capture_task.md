---
name: scroll-capture_task
description: 스크롤 캡처 구현 작업 태스크 (Issue17 + 스크롤 영역 기반 확장)
date: 2026-04-16
issue: Issue17
plan: _doc_work/plan/scroll-capture_plan.md
---

# 스크롤 캡처 구현 Task

# Task 1: ScreenCaptureConfig에 ScrollConfig 추가

* 파일: `fCapture/ScreenCaptureApp.swift`
* [ ] `struct ScrollConfig: Codable` 추가 (`StaticRegionConfig` 바로 아래)
* [ ] `ScreenCaptureConfig`에 `scrollConfig: ScrollConfig?` 필드 추가
* [ ] `CodingKeys`에 `scrollConfig` 추가
* [ ] `TargetType`에 `scrollCapture` 케이스 추가
* [ ] `TargetType.init(from:)` — `"scroll_capture"`, `"scroll"` 문자열 처리 추가
* [ ] `TargetType.encode(to:)` — `.scrollCapture` → `"scroll_capture"` 인코딩 추가
* [ ] `swift build -c release` 빌드 확인
* [ ] commit

# Task 2: ScrollCapture.swift 신규 파일 작성

* 파일: `fCapture/ScrollCapture.swift` (신규)
* [ ] `ScrollCaptureEngine` 클래스 선언 + `Config` 내부 구조체
* [ ] `captureWithScroll(windowID:config:shadow:)` — 스크롤 루프 메인 함수
* [ ] `postScrollEvent(at:amount:)` — CGEvent 스크롤 이벤트 전송
* [ ] `windowBounds(windowID:)` — 윈도우 위치/크기 조회
* [ ] `isScrollEnd(current:previous:)` — 하단 20% 픽셀 평균 차이로 끝 감지
* [ ] `stitchFrames(_:overlapRatio:)` — CoreGraphics CGContext 수직 합성
* [ ] `findOverlapHeight(previous:current:maxRatio:)` — 오버랩 픽셀 행 탐색
* [ ] `extractPixels(from:x:y:width:height:)` — CGImage 픽셀 추출 헬퍼
* [ ] commit

# Task 3: ScreenCaptureApp.swift 통합

* 파일: `fCapture/ScreenCaptureApp.swift`
* [ ] `getTargetList()` — `.scrollCapture` → `["scroll_capture"]` 추가
* [ ] `parseTargetType()` — `"scroll_capture"`, `"scroll"` 케이스 추가
* [ ] `captureSingleImage()` — `scroll_capture` 분기 추가 (맨 앞에 삽입)
* [ ] `printHelp()` — `-t` 옵션 목록에 `scroll_capture` 설명 추가
* [ ] commit

# Task 4: Package.swift 수정 + 빌드 검증

* 파일: `fCapture/Package.swift`
* [ ] `sources` 배열에 `"ScrollCapture.swift"` 추가
* [ ] `swift build -c release` 빌드 성공 확인
* [ ] `~/.bin/fCapture --help | grep scroll` 출력 확인
* [ ] commit

# Task 5: JSON 예제 설정 파일 추가

* 파일: `data/settings/20_scroll_capture.json` (신규), `data/settings/20_scroll_capture_qa.json` (신규)
* [ ] `20_scroll_capture.json` 생성 (`maxScrolls: 30`, 실사용용)
* [ ] `20_scroll_capture_qa.json` 생성 (`maxScrolls: 3`, `scrollDelay: 0.3` — QA timeout 15s 대응)
* [ ] TextEdit/Safari 열고 `./bin/fCapture data/settings/20_scroll_capture_qa.json` 단독 실행
* [ ] 생성된 PNG 파일 열어서 스티칭 결과 육안 확인
* [ ] `./bin/fCapture -t scroll_capture` CLI 옵션 실행 확인
* [ ] commit

# Task 6: QA 전수 실행

* 참조: `data/settings/*.json` (QA 스킬이 자동 감지, `timeout 15 ./bin/fCapture <파일>`)
* 사전 조건: TextEdit 또는 Safari를 열어 활성 윈도우 확보
* [ ] `./bin/fCapture data/settings/20_scroll_capture_qa.json` 단독 테스트 (exit 0 확인)
* [ ] `/test` 또는 `qa` 에이전트로 `data/settings/` 전수 QA 실행
* [ ] `20_scroll_capture_qa.json` ✅ 확인 (3회 스크롤 + 스티칭 성공)
* [ ] `20_scroll_capture.json` 타임아웃 시 SKIP으로 기록 (정상)
* [ ] 기존 00~19번 파일 전체 ✅ 유지 확인 (회귀 없음)
* [ ] 실패 항목 있으면 수정 후 재실행
* [ ] commit

---

# Task 7: PageDown/Up 기반 스크롤 방식 추가 및 기본값 설정 (Issue17_1)

* 관련 이슈: Issue17_1
* 파일: `fCapture/ScreenCaptureApp.swift`, `fCapture/ScrollCapture.swift`, `data/settings/`
* [ ] `ScrollConfig`에 `scrollMode: String` 필드 추가 (`"page"` 기본값, `"scroll"` 선택)
* [ ] PageDown 모드 구현: AppleScript `keystroke (page down)` 방식 (`targetApp` 필수)
* [ ] 스크롤 모드 유지: 기존 `do JavaScript "window.scrollBy(0, N)"` 방식
* [ ] CGEvent 방식(`postScrollEvent`): `scrollMode: "scroll"` + `targetApp` 미지정 시 사용
* [ ] CLI `--scroll` 옵션 추가 → `scrollMode: "scroll"` 강제 설정
* [ ] `noteForHuman.md`, `data/settings/` 예제 JSON 업데이트
* [ ] 빌드 및 동작 확인
* [ ] commit

# Task 8: 캡처 시작 전 화면 최상단 이동 기능 추가 (Issue17_2)

* 관련 이슈: Issue17_2
* 파일: `fCapture/ScrollCapture.swift`
* [ ] PageDown 모드: AppleScript `key code 115` (Home 키) 또는 `keystroke (home)` 로 최상단 이동
* [ ] 스크롤 모드: AppleScript `do JavaScript "window.scrollTo(0, 0)"` 로 최상단 이동
* [ ] 이동 후 `scrollDelay` 대기 후 첫 프레임 캡처 시작
* [ ] `ScrollConfig.scrollToTop: Bool` 옵션 추가 (기본값 `true`)
* [ ] 빌드 및 동작 확인
* [ ] commit

# Task 9: 스티칭 연결 품질 개선 (Issue17_3)

* 관련 이슈: Issue17_3
* 파일: `fCapture/ScrollCapture.swift`
* [ ] `findOverlapHeight`: 단일 행(1px) 비교 → 복수 행(5px) 평균 비교로 정확도 향상
* [ ] 오버랩 탐색 방향 개선: greedy 대신 상위 N개 후보 스코어링 후 최적값 선택
* [ ] 임계값 `avgDiff < 8.0` → 동적 임계값 (이미지 분산 기반) 검토
* [ ] 경계 영역 블렌딩: 단순 크롭 대신 2~3px 알파 블렌드로 연결선 제거
* [ ] 빌드 및 스티칭 결과 육안 확인
* [ ] commit

# Task 10: 스크롤 캡처 마우스 포인터 앱 자동 감지 (Issue17_4)

* 관련 이슈: Issue17_4
* 파일: `fCapture/ScrollCapture.swift`, `fCapture/ScreenCaptureApp.swift`
* [ ] `NSEvent.mouseLocation`(Flipped) 또는 `CGEventGetLocation`으로 현재 마우스 좌표 취득
* [ ] `CGWindowListCopyWindowInfo`로 포인터 위치에 겹치는 최상위 윈도우 ID 및 `kCGWindowOwnerName` 결정
* [ ] `ownerName` 기반으로 `activateApp()` 호출 및 스크롤 이벤트 전송 (AppleScript/CGEvent 자동 선택)
* [ ] `ScrollCaptureEngine.Config.targetApp` 필드 제거 또는 deprecated 처리
* [ ] JSON 설정에서 `target_app` 필드 없이도 동작하도록 `ScreenCaptureApp.swift` 호출부 수정
* [ ] 빌드 및 동작 확인
* [ ] commit

---

# 스크롤 영역 기반 캡처 (AX 단일 모듈)

> Design doc: `~/.gstack/projects/fCapture/nowage-main-design-20260416-172654.md` (APPROVED)
> Plan: `_doc_work/plan/scroll-region-capture_plan.md`

# Task 11: AX 속성 가용성 사전 검증 스파이크 (Step 0)

* 관련 이슈: Issue19
* 목적: 6개 대상 앱에서 AX 속성 가용성 확인 → Approach B 유지 여부 판정
* [ ] 검증 스크립트 작성 (Swift 또는 Python + pyobjc)
    - `AXUIElementCreateApplication(pid)` → 앱 요소 생성
    - `AXUIElementCopyElementAtPosition(app, mouseX, mouseY, &element)` → 요소 획득
    - 부모 체인 탐색 → `kAXRoleAttribute == "AXScrollArea"` 존재 여부
    - `kAXFrameAttribute` + `kAXSizeAttribute` 값 로깅
    - `kAXValueAttribute` 스크롤 위치값 로깅
* [ ] Safari에서 테스트 → AXScrollArea 노출 확인 + 좌표계 확인 (논리 px?)
* [ ] Chrome에서 테스트
* [ ] Finder에서 테스트
* [ ] Xcode에서 테스트
* [ ] Notes에서 테스트
* [ ] Terminal에서 테스트
* [ ] 결과 정리: 앱별 AXScrollArea/Frame/Value 가용성 매트릭스
* [ ] **판정**: kAXValueAttribute 4/6 이상 미노출 → Approach A로 축소 결정
* [ ] 좌표 변환 공식 확정: `relativeX = (axOriginX - windowOriginX) * backingScaleFactor`

# Task 12: AX 스크롤 영역 감지 모듈 (Step 1)

* 관련 이슈: Issue19
* 파일: `fCapture/ScrollCapture.swift`
* [ ] `import ApplicationServices` 추가
* [ ] `windowAtMousePointer()` 확장: PID 반환 추가
    - 반환 타입: `(windowID: CGWindowID, ownerName: String, ownerPID: pid_t)`
    - `kCGWindowOwnerPID` 에서 PID 추출
* [ ] `detectScrollAreaAX(pid:mousePoint:)` → `(frame: CGRect, scrollArea: AXUIElement)?` 신규
    - `AXUIElementCreateApplication(pid)` → 앱 요소
    - `AXUIElementCopyElementAtPosition(app, Float(x), Float(y), &element)` → 마우스 위치 요소
    - 부모 체인 탐색: `kAXParentAttribute` 반복 → `kAXRoleAttribute == "AXScrollArea"` 첫 번째(가장 깊은) 선택
    - `kAXPositionAttribute` → `AXValueGetValue(.cgPoint)` → CGPoint
    - `kAXSizeAttribute` → `AXValueGetValue(.cgSize)` → CGSize
    - 조합 → `CGRect` 반환
    - AX 권한 미부여 시 nil 반환 (graceful fallback)
* [ ] `swift build -c release` 빌드 확인
* [ ] commit

# Task 13: ScrollConfig region 필드 추가 (Step 2)

* 관련 이슈: Issue19
* 파일: `fCapture/ScreenCaptureApp.swift`, `fCapture/ScrollCapture.swift`
* [ ] `struct RegionRect: Codable { let x, y, width, height: Double }` 추가
* [ ] `ScrollConfig`에 `regionMode: String?`, `region: RegionRect?` 추가
* [ ] `CodingKeys`에 `regionMode`, `region` 추가
* [ ] `ScrollCaptureEngine.Config`에 대응 필드 추가:
    - `regionMode: RegionMode` enum (`.auto`, `.rect`, `.window`)
    - `region: CGRect?`
* [ ] `CLIOverrides`에 `--region`, `--region-rect` 파싱 추가
    - `--region auto|rect|window`
    - `--region-rect "x,y,w,h"` (윈도우 좌상단 기준, 논리 px, 정수)
* [ ] `mergeConfig()`에 regionMode/region 오버라이드 로직 추가
* [ ] `swift build -c release` 빌드 확인
* [ ] commit

# Task 14: 영역 기반 캡처 + 크롭 로직 (Step 3)

* 관련 이슈: Issue19
* 파일: `fCapture/ScrollCapture.swift`
* [ ] `resolveScrollRegion(config:windowBounds:pid:mousePoint:)` → `CGRect?` 신규
    - `regionMode` 분기:
        - `.auto`: `detectScrollAreaAX(pid, mousePoint)` → nil이면 nil (window fallback)
        - `.rect`: `config.region` → CGRect 변환
        - `.window`: nil (크롭 없음)
* [ ] `cropToScrollRegion(image:region:windowBounds:)` → `NSImage` 신규
    - 스크린 좌표 → 윈도우 내 상대좌표 변환
    - `backingScaleFactor` 배율 적용 (논리→물리 px)
    - `CGImage.cropping(to:)` 크롭
    - 다중 모니터: AX 프레임 원점 포함 스크린의 backingScaleFactor 사용
* [ ] `captureWithScroll()` 수정:
    - 스크롤 루프 시작 전 `resolveScrollRegion()` 호출
    - 각 프레임 캡처 후 `cropToScrollRegion()` 적용 (region이 nil이면 크롭 안 함)
    - 스크롤 이벤트 좌표를 스크롤 영역 중앙으로 변경
* [ ] Safari + Finder에서 동작 확인 (크롭 영역 정확성)
* [ ] commit

# Task 15: AX 스크롤 위치 추적 (Step 4, 선택적)

* 관련 이슈: Issue19
* 전제: Task 11 결과에서 4/6 이상 앱이 kAXValueAttribute 노출 시에만 진행
* 파일: `fCapture/ScrollCapture.swift`
* [ ] `getScrollPositionAX(scrollArea:)` → `Double?` 신규
    - `AXUIElementCopyAttributeValue(scrollArea, kAXValueAttribute, &value)`
    - AXValue → Double 변환
    - 미노출 시 nil 반환
* [ ] `isScrollEndAX(scrollArea:previousPosition:)` → `Bool` 신규
    - 스크롤 전후 위치값 비교
    - 2회 연속 변화 없으면 true (또는 maxValue 도달)
* [ ] `captureWithScroll()` 스크롤 루프에 AX 위치 확인 추가
    - 기존 `isScrollEnd()` 픽셀 비교 OR `isScrollEndAX()` 조건
    - AX 위치값 nil이면 픽셀 비교 단독 사용
* [ ] 스크롤 진행률 로그 출력: `logI("스크롤 진행: position/maxPosition")`
* [ ] 빌드 및 동작 확인
* [ ] commit

# Task 16: scrollToTop 통합 (Step 5)

* 관련 이슈: Issue19
* 파일: `fCapture/ScrollCapture.swift`
* [ ] `scrollToTop` 로직에서 스크롤 영역 중앙에 클릭 이벤트 전송 (포커스 확보)
    - `CGEvent(mouseEventSource:, mouseType: .leftMouseDown, ...)` → 영역 중앙
    - `CGEvent(mouseEventSource:, mouseType: .leftMouseUp, ...)` → 즉시 해제
* [ ] 이후 CGEvent Home 키 전송 (기존 방식 유지)
* [ ] scrollMode: scroll 시 스크롤 이벤트 좌표를 영역 중앙으로 타겟팅
* [ ] 빌드 및 동작 확인
* [ ] commit

# Task 17: JSON 설정 예제 + QA (Step 6)

* 관련 이슈: Issue19
* [ ] `data/settings/21_scroll_region_auto.json` 생성 (regionMode: auto, maxScrolls: 3)
* [ ] `data/settings/22_scroll_region_rect.json` 생성 (regionMode: rect, maxScrolls: 3)
* [ ] QA 필수 매트릭스 (12건):
    - [ ] auto + page + Safari
    - [ ] auto + page + Chrome
    - [ ] auto + page + Finder
    - [ ] auto + page + Xcode
    - [ ] auto + page + Notes
    - [ ] auto + page + Terminal
    - [ ] auto + scroll + Safari
    - [ ] auto + scroll + Chrome
    - [ ] auto + scroll + Finder
    - [ ] auto + scroll + Xcode
    - [ ] auto + scroll + Notes
    - [ ] auto + scroll + Terminal
* [ ] rect/window 하위 호환 확인 (1~2건)
* [ ] 기존 00~20번 전수 QA 통과 확인 (회귀 없음)
* [ ] commit

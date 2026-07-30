---
name: scroll-region-capture_plan
description: 스크롤 캡처를 윈도우 기반에서 스크롤 영역 기반으로 전환하는 계획 (AX 단일 모듈)
date: 2026-04-16
issue: Issue19
---

# 스크롤 영역 기반 캡처 Plan

> Design doc: `~/.gstack/projects/fCapture/nowage-main-design-20260416-172654.md` (APPROVED)

**Goal:** AX + CGEvent 단일 모듈로 모든 macOS 앱에서 스크롤 영역 자동 감지 + 크롭 캡처

**Approach:** B (AX + 스크롤 위치 추적)

**Architecture:** AXUIElement로 AXScrollArea 감지 → 프레임 크롭 → CGEvent 스크롤 → AX 위치값 이중 종료 확인

---

# 구현 단계

## Step 0: AX 속성 가용성 사전 검증 (필수 선행)

* 대상 6개 앱: Safari, Chrome, Finder, Xcode, Notes, Terminal
* 확인 항목:
    - AXScrollArea 역할 노출 여부
    - kAXFrameAttribute 좌표계 (논리 px vs 물리 px)
    - kAXValueAttribute 스크롤 위치 노출 여부
* **판정**: 4/6 이상 kAXValueAttribute 미노출 → Step 4 생략 (Approach A로 축소)
* 좌표 변환 공식:
    ```swift
    let scale = screen.backingScaleFactor
    let relativeX = (axFrameOriginX - windowOriginX) * scale
    let relativeY = (axFrameOriginY - windowOriginY) * scale
    ```

## Step 1: AX 스크롤 영역 감지 모듈

* `detectScrollAreaAX(pid:mousePoint:)` → `(frame: CGRect, scrollArea: AXUIElement)?`
* `windowAtMousePointer()` 확장: PID 반환 추가
* AX 권한 미부여 시 nil 반환 (graceful fallback)
* 중첩 스크롤: 부모 체인에서 **가장 깊은 (첫 번째)** AXScrollArea 선택

## Step 2: ScrollConfig region 필드 추가

* `regionMode: String?` (`"auto"` / `"rect"` / `"window"`), `region: RegionRect?` 추가
* CLI: `--region`, `--region-rect "x,y,w,h"` (윈도우 좌상단 기준, 논리 px)
* `ScrollCaptureEngine.Config`에 대응 필드 추가

## Step 3: 영역 기반 캡처 + 크롭

* `cropToScrollRegion(image:region:windowBounds:)` → NSImage
* 스크린 좌표 → 윈도우 상대좌표 변환 + backingScaleFactor 적용
* captureWithScroll() 루프에서 매 프레임 크롭

## Step 4: AX 스크롤 위치 추적 (Step 0 결과에 따라 선택적)

* `getScrollPositionAX(scrollArea:)` → Double?
* `isScrollEndAX()`: 2회 연속 위치 변화 없으면 끝 (또는 maxValue 도달)
* 기존 `isScrollEnd()` 픽셀 비교와 OR 조건

## Step 5: scrollToTop 통합

* CGEvent Home 키 전송 (기존 방식 유지)
* 스크롤 영역 중앙 좌표로 스크롤 이벤트 타겟팅

## Step 6: JSON 설정 예제 + QA

* `data/settings/21_scroll_region_auto.json` — regionMode: auto
* `data/settings/22_scroll_region_rect.json` — regionMode: rect
* QA: auto × {page, scroll} × 6개 앱 = 12 필수 테스트 + 전수 QA

---

# 파라미터 상호작용

| regionMode | scrollMode: page                                       | scrollMode: scroll                                            |
| :--------- | :----------------------------------------------------- | :------------------------------------------------------------ |
| `auto`     | AX 감지 영역 크롭 + CGEvent PageDown                  | AX 감지 영역 크롭 + CGEvent ScrollWheel (영역 중앙)          |
| `rect`     | 지정 영역 크롭 + CGEvent PageDown                      | 지정 영역 크롭 + CGEvent ScrollWheel (영역 중앙)              |
| `window`   | 기존 방식 그대로                                       | 기존 방식 그대로                                               |

* `regionMode`: **어디를** 캡처할지 (영역 감지)
* `scrollMode`: **어떻게** 스크롤할지 (이벤트 종류)
* 두 파라미터는 독립적으로 조합됨

# 제거 항목 (Safari 전용)

* ~~cssSelector~~ / ~~regionMode: "selector"~~ / ~~detectScrollRegionJS()~~ / ~~postElementScrollJS()~~
* AppleScript `do JavaScript` 스크롤: 레거시 유지, 2개 릴리즈 후 제거 예정

# 하위 호환

* regionMode 미지정 시 내부적으로 `"auto"` → AX 감지 시도 → 실패 시 window fallback
* 기존 JSON/CLI 100% 호환

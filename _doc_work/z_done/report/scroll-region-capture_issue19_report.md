---
name: scroll-region-capture_issue19_report
description: Issue19 Step 0 AX 속성 가용성 사전 검증 결과
date: 2026-04-16
issue: Issue19
---

# Step 0: AX 속성 가용성 사전 검증 결과

## 검증 환경

* macOS 15.5, backingScaleFactor: 1.0
* Accessibility 권한 부여 상태
* 검증 스크립트: `_doc_work/ax_spike_test.swift`

## 결과 매트릭스

| 앱           | AXScrollArea | Frame | kAXValue (ScrollArea) | scrollbar value | 비고                      |
| :----------- | :----------: | :---: | :-------------------: | :-------------: | :------------------------ |
| Safari       | ✅           | ✅    | ✅ (빈 문자열)        | 0               | orientation=Horizontal    |
| Chrome       | ❌           | -     | -                     | -               | AXScrollArea 미감지       |
| Finder       | ✅           | ✅    | ❌                    | -               | children=2                |
| Xcode        | ❌           | -     | -                     | -               | 메인 윈도우 없음 (미열림) |
| Notes        | ✅           | ✅    | ❌                    | -               | children=1                |
| Terminal     | ✅           | ✅    | ❌                    | 1               | scrollbar value 존재      |

## 판정

* **AXScrollArea 감지**: 4/6 앱 (Safari, Finder, Notes, Terminal)
* **kAXValue 노출**: 1/6 앱 (Safari만, 빈 문자열)
* **결론**: kAXValue 5/6 미노출 → **Step 4 생략, Approach A로 축소**

## 주요 발견

* Chrome: 자체 렌더링으로 AX ScrollArea 미노출 → window fallback 필수
* Xcode: 프로젝트 미열림으로 메인 윈도우 없음 → 열린 상태에서는 감지 가능할 수 있음
* ScrollBar의 value(0~1 범위)는 일부 앱에서 존재하나, ScrollArea 자체 value는 미노출
* AX 좌표: 논리 px 좌표계 확인 (backingScaleFactor 별도 적용 필요)
* regionMode 미지정 시 auto → AX 감지 시도 → 실패 시 window fallback 전략 유효

## 좌표 변환 공식 확정

```swift
let scale = screen.backingScaleFactor
let relativeX = (axFrameOriginX - windowOriginX) * scale
let relativeY = (axFrameOriginY - windowOriginY) * scale
```

## 구현 방향

* Step 1~3: AXScrollArea 감지 + Frame 크롭 구현 (4/6 앱 지원)
* Step 4: 생략 (kAXValue 미노출)
* Step 5~6: scrollToTop 통합 + QA
* Chrome/Xcode 미감지 시 window fallback (기존 방식 유지)

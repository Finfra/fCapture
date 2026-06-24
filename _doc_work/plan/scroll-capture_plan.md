---
name: scroll-capture_plan
description: fCapture 스크롤 캡처 기능 구현 계획
date: 2026-04-16
issue: Issue17
task: _doc_work/tasks/scroll-capture_task.md

---

# 스크롤 캡처 구현 Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** fCapture CLI에 스크롤 캡처 기능 추가 — 대상 윈도우를 자동 스크롤하며 반복 캡처한 이미지를 수직으로 스티칭하여 긴 스크롤 화면 한 장 출력

**Architecture:**
`ScrollCaptureEngine` 신규 클래스가 스크롤 이벤트(CGEvent) 전송→캡처→픽셀 비교 루프를 담당하고, `ScreenCaptureApp.swift`의 기존 `captureSingleImage()` 분기에 `scroll_capture` 케이스를 추가한다. 이미지 합성은 CoreGraphics CGContext 직접 조작으로 처리한다.

**Tech Stack:** Swift 5.9, CoreGraphics, AppKit, CGEvent, NSBitmapImageRep

---

# 파일 구조

| 파일                                   | 변경 유형 | 역할                                                                                                                                                 |
| :------------------------------------- | :-------- | :--------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fCapture/ScrollCapture.swift`         | **신규**  | `ScrollCaptureEngine`: 스크롤 루프, 스크롤 끝 감지, 이미지 스티칭                                                                                    |
| `fCapture/ScreenCaptureApp.swift`      | 수정      | `TargetType` 확장, `ScreenCaptureConfig`에 `scrollConfig` 추가, `captureSingleImage()`에 분기 추가, `parseTargetType()` 확장, `printHelp()` 업데이트 |
| `fCapture/Package.swift`               | 수정      | `ScrollCapture.swift` sources에 추가                                                                                                                 |
| `data/settings/20_scroll_capture.json` | **신규**  | 스크롤 캡처 예제 설정                                                                                                                                |

---

# Task 1: `ScreenCaptureConfig`에 ScrollConfig 추가

**Files:**
- Modify: `fCapture/ScreenCaptureApp.swift`

## 변경 위치

[ScreenCaptureApp.swift:254-368](fCapture/ScreenCaptureApp.swift#L254-L368) — `ScreenCaptureConfig` 구조체 내부

- [ ] **Step 1: `ScrollConfig` 구조체 추가**

`struct StaticRegionConfig` 바로 아래에 삽입 ([ScreenCaptureApp.swift:309](fCapture/ScreenCaptureApp.swift#L309) 이후):

```swift
struct ScrollConfig: Codable {
    let scrollAmount: Int?    // 스크롤 클릭 단위 (기본 8)
    let scrollDelay: Double?  // 스크롤 후 대기 시간(초, 기본 0.5)
    let maxScrolls: Int?      // 최대 스크롤 횟수 (기본 30)
    let overlapRatio: Double? // 오버랩 감지 비율 (기본 0.25)
}
```

- [ ] **Step 2: `ScreenCaptureConfig`에 `scrollConfig` 필드 추가**

[ScreenCaptureApp.swift:255-262](fCapture/ScreenCaptureApp.swift#L255-L262) — `struct ScreenCaptureConfig` 선언부:

```swift
// 기존 필드 끝에 추가
var scrollConfig: ScrollConfig?
```

- [ ] **Step 3: `CodingKeys`에 `scrollConfig` 추가**

[ScreenCaptureApp.swift:265-269](fCapture/ScreenCaptureApp.swift#L265-L269):

```swift
enum CodingKeys: String, CodingKey {
    case capturePath, capturePathArray, target, fileFormat, staticRegion, result, backupOtherScreen, shadow
    case windowFlash = "window_flash"
    case scrollConfig  // 추가
}
```

- [ ] **Step 4: `TargetType`에 `scrollCapture` 케이스 추가**

[ScreenCaptureApp.swift:326-368](fCapture/ScreenCaptureApp.swift#L326-L368) — `enum TargetType`:

```swift
enum TargetType: Codable {
    case single(String)
    case multiple([String])
    case all
    case staticRegion
    case region
    case scrollCapture  // 추가

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            if stringValue == "all" {
                self = .all
            } else if stringValue == "staticRegion" || stringValue == "region_static" {
                self = .staticRegion
            } else if stringValue == "region_user" {
                self = .region
            } else if stringValue == "scroll_capture" || stringValue == "scroll" {
                self = .scrollCapture  // 추가
            } else {
                self = .single(stringValue)
            }
        } else if let arrayValue = try? container.decode([String].self) {
            self = .multiple(arrayValue)
        } else {
            throw DecodingError.typeMismatch(TargetType.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String, [String], 'all', 'staticRegion', 'region_user', or 'scroll_capture'"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let value): try container.encode(value)
        case .multiple(let values): try container.encode(values)
        case .all: try container.encode("all")
        case .staticRegion: try container.encode("staticRegion")
        case .region: try container.encode("region")
        case .scrollCapture: try container.encode("scroll_capture")  // 추가
        }
    }
}
```

- [ ] **Step 5: 빌드 확인**

```bash
cd /Users/nowage/_git/__all/fCapture/fCapture && swift build -c release 2>&1 | tail -5
```

예상 출력: `Build complete!` (오류 없음)

- [ ] **Step 6: 커밋**

```bash
cd /Users/nowage/_git/__all/fCapture
git add fCapture/ScreenCaptureApp.swift
git commit -m "Feat(Config): TargetType에 scrollCapture 케이스 및 ScrollConfig 구조체 추가"
```

---

# Task 2: `ScrollCapture.swift` 신규 파일 작성

**Files:**
- Create: `fCapture/ScrollCapture.swift`

스크롤 캡처 엔진 전체. CGEvent로 스크롤→캡처→픽셀 비교→스티칭 루프.

- [ ] **Step 1: `ScrollCapture.swift` 생성**

```swift
import Foundation
import CoreGraphics
import AppKit

// MARK: - ScrollCaptureEngine

class ScrollCaptureEngine {

    // MARK: - Config

    struct Config {
        let scrollAmount: Int     // CGEvent 스크롤 클릭 단위 (양수=아래로)
        let scrollDelay: Double   // 스크롤 후 렌더링 대기(초)
        let maxScrolls: Int       // 최대 스크롤 횟수
        let overlapRatio: Double  // 오버랩 탐색 범위 (이미지 높이 대비 비율)

        static let `default` = Config(
            scrollAmount: 8,
            scrollDelay: 0.5,
            maxScrolls: 30,
            overlapRatio: 0.25
        )
    }

    // MARK: - Public Entry Point

    /// 지정 windowID 윈도우를 스크롤하며 캡처 → 스티칭된 NSImage 반환
    func captureWithScroll(
        windowID: CGWindowID,
        config: Config = .default,
        shadow: Bool = false
    ) throws -> NSImage {
        let screenCapture = ScreenCapture()
        let options = ScreenCapture.CaptureOptions(includeWindowShadow: shadow)

        guard let bounds = windowBounds(windowID: windowID) else {
            throw ScreenCapture.ScreenCaptureError.captureFailure("스크롤 캡처: 윈도우 위치를 가져올 수 없습니다")
        }

        // 스크롤 이벤트를 보낼 윈도우 중앙 좌표
        let scrollPoint = CGPoint(x: bounds.midX, y: bounds.midY)

        var frames: [NSImage] = []

        // 첫 번째 프레임
        let first = try screenCapture.captureWindow(windowID: windowID, options: options)
        frames.append(first)
        logI("스크롤 캡처 시작: 최대 \(config.maxScrolls)회 스크롤")

        for i in 0..<config.maxScrolls {
            // 스크롤 다운 이벤트 전송
            postScrollEvent(at: scrollPoint, amount: config.scrollAmount)
            Thread.sleep(forTimeInterval: config.scrollDelay)

            let frame = try screenCapture.captureWindow(windowID: windowID, options: options)

            // 스크롤 끝 감지: 현재 프레임이 이전과 동일하면 종료
            if isScrollEnd(current: frame, previous: frames.last!) {
                logI("스크롤 끝 감지 (\(i + 1)회차). 캡처 종료")
                break
            }

            frames.append(frame)
            logD("스크롤 캡처 \(i + 1)/\(config.maxScrolls) 완료")
        }

        logI("총 \(frames.count)개 프레임 수집, 스티칭 시작")
        return try stitchFrames(frames, overlapRatio: config.overlapRatio)
    }

    // MARK: - CGEvent Scroll

    /// CGEvent를 사용하여 스크롤 이벤트 전송 (양수: 아래로, 음수: 위로)
    private func postScrollEvent(at point: CGPoint, amount: Int) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: Int32(-amount),  // 음수 = 아래로 스크롤
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.location = point
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Window Bounds

    private func windowBounds(windowID: CGWindowID) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
              let info = list.first,
              let dict = info[kCGWindowBounds as String] as? [String: CGFloat],
              let x = dict["X"], let y = dict["Y"],
              let w = dict["Width"], let h = dict["Height"] else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Scroll End Detection

    /// 현재 프레임과 이전 프레임의 하단 20% 픽셀을 비교하여 스크롤 끝 여부 판단
    private func isScrollEnd(current: NSImage, previous: NSImage) -> Bool {
        guard let curCG = current.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let preCG = previous.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }

        let h = curCG.height
        let w = curCG.width
        let compareH = max(10, h / 5)  // 하단 20%

        // 하단 compareH 행의 픽셀 데이터 추출
        guard let curPixels = extractPixels(from: curCG, x: 0, y: 0, width: w, height: compareH),
              let prePixels = extractPixels(from: preCG, x: 0, y: 0, width: w, height: compareH) else { return false }

        // 평균 픽셀 차이 계산
        var totalDiff: Int = 0
        let count = min(curPixels.count, prePixels.count)
        for i in 0..<count {
            totalDiff += abs(Int(curPixels[i]) - Int(prePixels[i]))
        }
        let avgDiff = Double(totalDiff) / Double(count)
        return avgDiff < 3.0  // 3 이하 = 동일한 것으로 판단
    }

    // MARK: - Image Stitching

    /// 여러 프레임을 오버랩 감지하여 수직으로 합성
    func stitchFrames(_ frames: [NSImage], overlapRatio: Double) throws -> NSImage {
        guard !frames.isEmpty else {
            throw ScreenCapture.ScreenCaptureError.captureFailure("스티칭 대상 프레임이 없습니다")
        }
        guard frames.count > 1 else { return frames[0] }

        guard let firstCG = frames[0].cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ScreenCapture.ScreenCaptureError.captureFailure("첫 프레임 CGImage 변환 실패")
        }

        let frameW = firstCG.width
        let frameH = firstCG.height

        // 각 프레임의 오버랩 크기 계산 (픽셀 단위)
        var overlapHeights: [Int] = []
        for i in 1..<frames.count {
            let overlap = findOverlapHeight(
                previous: frames[i - 1],
                current: frames[i],
                maxRatio: overlapRatio
            )
            overlapHeights.append(overlap)
        }

        // 총 출력 높이 = 첫 프레임 높이 + 이후 프레임의 (높이 - 오버랩)
        let totalHeight = frameH + overlapHeights.enumerated().reduce(0) { acc, pair in
            let (i, overlap) = pair
            guard let cgImg = frames[i + 1].cgImage(forProposedRect: nil, context: nil, hints: nil) else { return acc }
            return acc + cgImg.height - overlap
        }

        guard let context = CGContext(
            data: nil,
            width: frameW,
            height: totalHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ScreenCapture.ScreenCaptureError.captureFailure("합성 컨텍스트 생성 실패")
        }

        // CoreGraphics 좌표: Y축이 아래에서 위로 증가
        // 첫 프레임: 최상단에 배치 → Y = totalHeight - frameH
        var currentTop = totalHeight

        for (index, frame) in frames.enumerated() {
            guard let cgImg = frame.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            let imgH = cgImg.height

            let skipTop = (index == 0) ? 0 : overlapHeights[index - 1]
            let drawH = imgH - skipTop

            if drawH <= 0 { continue }

            currentTop -= drawH
            let destRect = CGRect(x: 0, y: currentTop, width: frameW, height: drawH)

            // 이미지의 skipTop 행을 건너뛰고 나머지를 그리기
            // CGImage.cropping: Y는 이미지 하단 기준 (CG 좌표계)
            // 이미지 상단 skipTop 행 = CG 기준 하단에서 (imgH - skipTop)부터
            if skipTop > 0 {
                // 상단 skipTop 픽셀 제거 = 하단 (imgH - skipTop) 픽셀만 사용
                let cropRect = CGRect(x: 0, y: 0, width: frameW, height: imgH - skipTop)
                if let cropped = cgImg.cropping(to: cropRect) {
                    context.draw(cropped, in: destRect)
                }
            } else {
                context.draw(cgImg, in: destRect)
            }
        }

        guard let resultCG = context.makeImage() else {
            throw ScreenCapture.ScreenCaptureError.captureFailure("최종 이미지 생성 실패")
        }

        logI("스티칭 완료: \(frameW)x\(totalHeight)px")
        return NSImage(cgImage: resultCG, size: NSSize(width: frameW, height: totalHeight))
    }

    // MARK: - Overlap Detection

    /// 이전 프레임 하단과 현재 프레임 상단을 비교하여 오버랩 높이(픽셀) 반환
    private func findOverlapHeight(previous: NSImage, current: NSImage, maxRatio: Double) -> Int {
        guard let preCG = previous.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let curCG = current.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 0 }

        let h = preCG.height
        let w = preCG.width
        let maxOverlap = Int(Double(h) * maxRatio)

        // 이전 프레임 하단 1행씩 현재 프레임 상단과 비교
        // 가장 큰 오버랩부터 탐색 (greedy)
        for overlap in stride(from: maxOverlap, through: 5, by: -1) {
            // 이전 프레임의 (h - overlap)번째 행 (0-indexed, 위에서부터)
            // CG 좌표: 이미지 하단에서 (overlap - 1)번째 행 = y = overlap - 1
            guard let preRow = extractPixels(from: preCG, x: 0, y: overlap - 1, width: min(w, 100), height: 1),
                  let curRow = extractPixels(from: curCG, x: 0, y: h - overlap, width: min(w, 100), height: 1) else {
                continue
            }

            var diff = 0
            let count = min(preRow.count, curRow.count)
            for i in 0..<count {
                diff += abs(Int(preRow[i]) - Int(curRow[i]))
            }
            let avgDiff = Double(diff) / Double(max(1, count))

            if avgDiff < 8.0 {
                return overlap
            }
        }
        return 0
    }

    // MARK: - Pixel Extraction

    /// CGImage에서 지정 영역의 픽셀 데이터(RGBA) 추출
    /// - Note: CG 좌표계 — y=0이 이미지 하단
    private func extractPixels(from cgImage: CGImage, x: Int, y: Int, width: Int, height: Int) -> [UInt8]? {
        let bytesPerPixel = 4
        var data = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let ctx = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // 원하는 영역을 (0,0)에 그리기 위해 이미지를 오프셋으로 이동
        ctx.draw(cgImage, in: CGRect(
            x: -x,
            y: -(cgImage.height - y - height),
            width: cgImage.width,
            height: cgImage.height
        ))
        return data
    }
}
```

- [ ] **Step 2: 빌드 (Package.swift 수정 전이므로 아직 소스에 포함 안 됨 — 이 step은 Task 4 이후로 이동)**

파일 생성 후 Task 4에서 Package.swift 수정 시 함께 빌드 검증.

- [ ] **Step 3: 커밋 (파일 생성)**

```bash
cd /Users/nowage/_git/__all/fCapture
git add fCapture/ScrollCapture.swift
git commit -m "Feat(ScrollCapture): ScrollCaptureEngine 신규 파일 추가"
```

---

# Task 3: `ScreenCaptureApp.swift` 통합

**Files:**
- Modify: `fCapture/ScreenCaptureApp.swift`

`captureSingleImage()`, `getTargetList()`, `parseTargetType()`, `printHelp()` 4곳 수정.

- [ ] **Step 1: `getTargetList()`에 `scrollCapture` 케이스 추가**

[ScreenCaptureApp.swift:1124-1138](fCapture/ScreenCaptureApp.swift#L1124-L1138) — `getTargetList()`:

```swift
static func getTargetList(from targetType: ScreenCaptureConfig.TargetType, using screenCapture: ScreenCapture) -> [String] {
    switch targetType {
    case .single(let target):
        return [target]
    case .multiple(let targets):
        return targets
    case .all:
        let displays = screenCapture.getAvailableDisplays()
        return displays.map { "screen:\($0.displayNumber)" }
    case .staticRegion:
        return ["staticRegion"]
    case .region:
        return ["region"]
    case .scrollCapture:          // 추가
        return ["scroll_capture"]
    }
}
```

- [ ] **Step 2: `parseTargetType()`에 `scroll_capture` 추가**

[ScreenCaptureApp.swift:634-656](fCapture/ScreenCaptureApp.swift#L634-L656) — `parseTargetType()`:

```swift
private static func parseTargetType(_ value: String) -> ScreenCaptureConfig.TargetType? {
    let lowerValue = value.lowercased()
    switch lowerValue {
    case "all":
        return .all
    case "region", "region_user":
        return .region
    case "staticregion", "region_static":
        return .staticRegion
    case "scroll_capture", "scroll":   // 추가
        return .scrollCapture
    case "window", "window_active", "window_pointer", "window_flash":
        return .single(value)
    default:
        if lowerValue.hasPrefix("screen:") {
            let numberPart = String(lowerValue.dropFirst(7))
            if Int(numberPart) != nil {
                return .single(value)
            }
        }
        return nil
    }
}
```

- [ ] **Step 3: `captureSingleImage()`에 `scroll_capture` 분기 추가**

[ScreenCaptureApp.swift:1141-1194](fCapture/ScreenCaptureApp.swift#L1141-L1194) — `captureSingleImage()` 함수 첫 번째 `if` 블록 앞에 삽입:

```swift
static func captureSingleImage(target: String, using screenCapture: ScreenCapture, config: ScreenCaptureConfig, resultFormat: ScreenCaptureConfig.ResultFormat) throws -> NSImage {
    // 스크롤 캡처
    if target == "scroll_capture" {
        guard let windowID = screenCapture.getFrontmostWindowID() else {
            throw ScreenCapture.ScreenCaptureError.captureFailure("스크롤 캡처: 활성 윈도우를 찾을 수 없습니다")
        }
        if resultFormat == .text {
            logI("스크롤 캡처 모드 시작: 활성 윈도우(\(windowID))를 대상으로 자동 스크롤")
        }
        let sc = config.scrollConfig
        let engineConfig = ScrollCaptureEngine.Config(
            scrollAmount: sc?.scrollAmount ?? 8,
            scrollDelay: sc?.scrollDelay ?? 0.5,
            maxScrolls: sc?.maxScrolls ?? 30,
            overlapRatio: sc?.overlapRatio ?? 0.25
        )
        let engine = ScrollCaptureEngine()
        return try engine.captureWithScroll(
            windowID: windowID,
            config: engineConfig,
            shadow: config.shadow ?? false
        )
    } else if target == "region" {
        // ... 기존 코드 유지
```

- [ ] **Step 4: `printHelp()`에 `scroll_capture` 옵션 추가**

[ScreenCaptureApp.swift:840-880](fCapture/ScreenCaptureApp.swift#L840-L880) — `-t` 옵션 설명 부분에 아래 행 추가:

```
print("                             - scroll_capture: 활성 윈도우 자동 스크롤 캡처 (스티칭)")
```

위치: `window_flash` 설명 바로 아래.

- [ ] **Step 5: 빌드 (Package.swift 수정 이전이므로 오류 예상)**

이 단계에서는 커밋만 진행, 빌드는 Task 4에서 Package.swift 수정 후 수행.

- [ ] **Step 6: 커밋**

```bash
cd /Users/nowage/_git/__all/fCapture
git add fCapture/ScreenCaptureApp.swift
git commit -m "Feat(App): scroll_capture 타겟 통합 (getTargetList/parseTargetType/captureSingleImage)"
```

---

# Task 4: Package.swift 수정 + 빌드 검증

**Files:**
- Modify: `fCapture/Package.swift`

- [ ] **Step 1: `sources`에 `ScrollCapture.swift` 추가**

[Package.swift:18](fCapture/Package.swift#L18) 현재:

```swift
sources: ["ScreenCaptureApp.swift", "ScreenCapture.swift"],
```

변경 후:

```swift
sources: ["ScreenCaptureApp.swift", "ScreenCapture.swift", "ScrollCapture.swift"],
```

- [ ] **Step 2: Release 빌드**

```bash
cd /Users/nowage/_git/__all/fCapture/fCapture && swift build -c release 2>&1
```

예상 출력:
```
Build complete!
```

오류 발생 시: 컴파일 에러 메시지를 확인하여 Task 2/3의 코드를 수정함.

- [ ] **Step 3: 기본 동작 확인**

```bash
~/.bin/fCapture --help | grep scroll
```

예상 출력:
```
                             - scroll_capture: 활성 윈도우 자동 스크롤 캡처 (스티칭)
```

- [ ] **Step 4: 커밋**

```bash
cd /Users/nowage/_git/__all/fCapture
git add fCapture/Package.swift
git commit -m "Chore(Build): Package.swift에 ScrollCapture.swift 추가"
```

---

# Task 5: JSON 예제 설정 파일 추가

**Files:**
- Create: `data/settings/20_scroll_capture.json`

- [ ] **Step 1: `20_scroll_capture.json` 생성**

```json
{
    "capturePath": "~/Desktop",
    "target": "scroll_capture",
    "fileFormat": "scroll_%d_%T",
    "scrollConfig": {
        "scrollAmount": 8,
        "scrollDelay": 0.5,
        "maxScrolls": 30,
        "overlapRatio": 0.25
    }
}
```

필드 설명:
- `scrollAmount`: 스크롤 한 번에 이동하는 라인 단위 (8 = 보통 속도)
- `scrollDelay`: 스크롤 후 페이지 렌더링 대기 시간(초)
- `maxScrolls`: 무한 루프 방지용 최대 스크롤 횟수
- `overlapRatio`: 오버랩 탐색 범위 (0.25 = 이미지 높이의 25%)

- [ ] **Step 2: QA 자동 실행용 경량 설정 파일 추가**

QA 스킬은 `timeout 15`로 각 설정 파일을 실행함. `maxScrolls: 30`이면 15초 초과 가능성 있음.
QA 전용 경량 파일 `data/settings/20_scroll_capture_qa.json` 도 함께 생성:

```json
{
    "capturePath": "~/Desktop",
    "target": "scroll_capture",
    "fileFormat": "scroll_qa_%d_%T",
    "scrollConfig": {
        "scrollAmount": 8,
        "scrollDelay": 0.3,
        "maxScrolls": 3,
        "overlapRatio": 0.25
    }
}
```

- `maxScrolls: 3` + `scrollDelay: 0.3` → 최대 약 2~3초 내 완료
- 활성 윈도우가 없으면 exit 1 (QA 결과: ❌ — 사전 조건 필요로 기록)

- [ ] **Step 3: 빌드 후 수동 통합 테스트**

```bash
# TextEdit 또는 Safari 열어두고 실행
~/.bin/fCapture data/settings/20_scroll_capture.json
```

예상 출력 (text 모드):
```
스크롤 캡처 시작: 최대 30회 스크롤
스크롤 캡처 1/30 완료
...
스크롤 끝 감지 (N회차). 캡처 종료
총 N개 프레임 수집, 스티칭 시작
스티칭 완료: WxH px
스크린샷이 저장되었습니다: ~/Desktop/scroll_YYYYMMDD_HHMMSS.png
```

- [ ] **Step 4: CLI 옵션으로 실행 테스트**

```bash
~/.bin/fCapture -t scroll_capture
```

예상: 활성 윈도우 스크롤 캡처 후 ~/Desktop에 파일 저장

- [ ] **Step 5: 커밋**

```bash
cd /Users/nowage/_git/__all/fCapture
git add data/settings/20_scroll_capture.json data/settings/20_scroll_capture_qa.json
git commit -m "Docs(Settings): scroll_capture 예제 및 QA 경량 설정 파일 추가"
```

---

# 구현 주의사항

## CGEvent 스크롤 방향
- `CGEvent(scrollWheelEvent2Source:)` — `wheel1` 값:
    - 양수: **위로** 스크롤 (내용이 위로 이동)
    - 음수: **아래로** 스크롤 (내용이 아래로 이동, 페이지 다운)
- `units: .line` 기준 값 8 ≈ 보통 속도. 빠른 스크롤이 필요하면 15~20 사용

## CoreGraphics Y축 좌표계
- `CGContext`는 Y=0이 **하단**
- `CGImage.cropping(to:)` 는 **이미지 하단을 원점**으로 동작
- ex) 이미지 높이 1000px에서 상단 200px를 제거하려면:
    - `cropping(to: CGRect(x:0, y:0, width:w, height:800))` → 하단 800px 추출

## 스크롤 끝 감지 임계값
- `avgDiff < 3.0`: 평균 픽셀 차이 3 미만 = 동일 화면으로 판단
- JPEG 압축, 애니메이션이 있는 페이지는 임계값을 높여야 할 수 있음 (ex: 5.0~8.0)
- 향후 `ScreenCaptureConfig`에 `sameFrameThreshold` 파라미터 추가 가능

## 권한
- `CGEvent.tapCreate` 및 `CGEvent.post`는 기존 스크린 녹화 권한으로 동작
- 별도 Accessibility 권한 요청은 불필요 (읽기 전용 이벤트 관찰이 아닌 이벤트 전송이기 때문)
- 단, 일부 보호된 앱(은행 앱 등)은 CGEvent 수신을 차단할 수 있음

## 테스트 권장 대상
- Safari (긴 웹페이지)
- TextEdit (긴 문서)
- Terminal (긴 로그 출력)

---

# Task 6: QA 전수 실행

**Files:**
- 참조: `data/settings/*.json` (QA 스킬이 자동 감지)

QA 스킬 동작:
1. `ls data/settings/*.json` — 설정 파일 전체 목록 수집
2. 각 파일에 대해 `timeout 15 ./bin/fCapture <파일>` 실행
3. exit code 0 = ✅, 그 외 = ❌, 15초 초과 = 타임아웃
4. 결과 테이블로 보고

## scroll_capture QA 특성

| 설정 파일 | 예상 결과 | 비고 |
| :--- | :--- | :--- |
| `20_scroll_capture_qa.json` | ✅ (활성 윈도우 있을 때) / ❌ (없을 때) | maxScrolls:3 → 15초 내 완료 |
| `20_scroll_capture.json` | ⚠️ 타임아웃 가능 | maxScrolls:30 → 시간 초과 위험 |

- [ ] **Step 1: QA 스킬 실행**

```bash
cd /Users/nowage/_git/__all/fCapture
# TextEdit 또는 Safari를 미리 열어 활성 윈도우 확보
./bin/fCapture data/settings/20_scroll_capture_qa.json  # 사전 단독 테스트
```

- [ ] **Step 2: 전수 QA 실행**

```bash
# qa 에이전트 또는 /test 커맨드로 data/settings/ 전수 실행
# 각 파일: timeout 15 ./bin/fCapture <파일>
```

예상 결과 테이블 (신규 항목):

```
| 20 | 20_scroll_capture_qa.json | ✅ | scroll 3회, WxHpx 스티칭 |
| 21 | 20_scroll_capture.json    | ⚠️ | maxScrolls:30 — 타임아웃 시 SKIP |
```

- [ ] **Step 3: 기존 설정 파일 회귀 확인**

기존 00~19번 파일이 모두 ✅인지 확인. scroll_capture 추가로 인한 회귀 없어야 함.

- [ ] **Step 4: 커밋 (필요 시 수정 후)**

```bash
git add .
git commit -m "Test(QA): 스크롤 캡처 전수 QA 통과 확인"
```

---

# Self-Review Checklist

- [x] **Spec coverage**: 스크롤 루프, 끝 감지, 스티칭, CLI 통합, JSON 예제, QA 단계 모두 포함
- [x] **Placeholder scan**: TBD, TODO 없음, 모든 코드 블록 완성
- [x] **Type consistency**:
    - `ScrollCaptureEngine.Config` → Task 2, Task 3 모두 동일 타입 참조
    - `ScreenCaptureConfig.ScrollConfig` → Task 1 정의, Task 3 사용
    - `windowID: CGWindowID` → `getFrontmostWindowID()` 반환 타입과 일치
    - `ScreenCapture.ScreenCaptureError.captureFailure` → 기존 에러 타입 재사용
- [x] **QA 통합**: `timeout 15` 제약 감안한 경량 QA 설정(`_qa.json`) 별도 추가, scroll_capture 사전 조건(활성 윈도우 필요) 명시

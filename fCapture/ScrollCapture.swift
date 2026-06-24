import Foundation
import CoreGraphics
import AppKit
import ApplicationServices
import Vision

// MARK: - ScrollCaptureEngine

class ScrollCaptureEngine {

    // MARK: - Config

    struct Config {
        let scrollAmount: Int     // CGEvent 스크롤 라인 단위 (양수 = 아래로)
        let scrollDelay: Double   // 스크롤 후 렌더링 대기(초)
        let maxScrolls: Int       // 최대 스크롤 횟수
        let overlapRatio: Double  // 오버랩 탐색 범위 (이미지 높이 대비 비율)
        let scrollMode: ScrollMode  // 스크롤 방식 (기본: .page)
        let scrollToTop: Bool     // 캡처 시작 전 최상단 이동 여부 (기본: true)
        let excludeApps: [String] // scrollToTop 을 건너뛸 예외 앱 목록
        let targetApp: String?    // 명시적 타겟 앱 지정 (nil이면 마우스 포인터 자동 감지)
        let regionMode: RegionMode // 영역 모드 (기본: .auto)
        let region: CGRect?       // regionMode: .rect 일 때 수동 지정 영역 (윈도우 좌상단 기준, 논리 px)

        enum ScrollMode: String {
            case page = "page"    // PageDown 키 기반 (기본값, Accessibility 권한 불필요)
            case scroll = "scroll"  // 마우스 스크롤 기반 (JavaScript scrollBy)
        }

        enum RegionMode: String {
            case auto = "auto"      // AX 감지 → 실패 시 window fallback
            case rect = "rect"      // 수동 지정 영역
            case window = "window"  // 윈도우 전체 (기존 방식)
        }

        static let `default` = Config(
            scrollAmount: 8,
            scrollDelay: 0.5,
            maxScrolls: 30,
            overlapRatio: 1.0,
            scrollMode: .page,
            scrollToTop: true,
            excludeApps: [],
            targetApp: nil,
            regionMode: .auto,
            region: nil
        )
    }

    // MARK: - Public Entry Point

    /// 마우스 포인터 위치의 앱을 자동 감지하여 스크롤하며 캡처 → 스티칭된 NSImage 반환
    /// fallbackWindowID: 포인터 감지 실패 시 사용할 윈도우 ID
    func captureWithScroll(
        fallbackWindowID: CGWindowID,
        config: Config = .default,
        shadow: Bool = false
    ) throws -> NSImage {
        let screenCapture = ScreenCapture()
        let options = ScreenCapture.CaptureOptions(includeWindowShadow: shadow)

        // 앱 감지: targetApp 명시 시 해당 앱 활성화, 미지정 시 마우스 포인터 자동 감지
        var targetWindowID = fallbackWindowID
        var detectedAppName: String? = nil
        var detectedPID: pid_t? = nil

        if let explicitApp = config.targetApp {
            // 명시적 타겟 앱 지정: 활성화 후 frontmost 윈도우 사용
            activateApp(explicitApp)
            Thread.sleep(forTimeInterval: 0.6)
            detectedAppName = explicitApp
            // 활성화된 앱의 frontmost 윈도우 ID 탐색
            if let windowList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
            ) as? [[String: Any]] {
                for info in windowList {
                    if let owner = info[kCGWindowOwnerName as String] as? String,
                       owner == explicitApp,
                       let wid = info[kCGWindowNumber as String] as? CGWindowID,
                       let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                       let layer = info[kCGWindowLayer as String] as? Int, layer == 0 {
                        targetWindowID = wid
                        detectedPID = pid
                        logI("targetApp '\(explicitApp)' 활성화 → 윈도우 ID: \(wid)")
                        break
                    }
                }
            }
        } else if let (pointerWindowID, ownerName, ownerPID) = windowAtMousePointer() {
            targetWindowID = pointerWindowID
            detectedAppName = ownerName
            detectedPID = ownerPID
            logI("마우스 포인터 앱 감지: '\(ownerName)' (윈도우 ID: \(pointerWindowID), PID: \(ownerPID))")
        } else {
            logW("마우스 포인터 위치 앱을 감지할 수 없어 fallback 윈도우 사용 (ID: \(fallbackWindowID))")
        }

        guard let bounds = windowBounds(windowID: targetWindowID) else {
            throw ScreenCapture.ScreenCaptureError.captureFailure("스크롤 캡처: 윈도우 위치를 가져올 수 없습니다")
        }

        // 스크롤 영역 감지 (Issue19 Step 3)
        let scrollRegion = resolveScrollRegion(config: config, windowBounds: bounds, pid: detectedPID)
        let scrollPoint: CGPoint
        if let region = scrollRegion {
            // 스크롤 영역 중앙으로 스크롤 이벤트 타겟팅
            scrollPoint = CGPoint(x: region.midX, y: region.midY)
            logI("스크롤 영역 크롭 활성: \(region)")
        } else {
            scrollPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        }

        // 캡처 시작 전 최상단 이동 (Issue17_2, Issue19 Step 5 통합)
        let isExcludedApp = detectedAppName.map { config.excludeApps.contains($0) } ?? false
        if config.scrollToTop {
            if isExcludedApp {
                logI("예외 앱('\(detectedAppName!)')이므로 최상단 이동 건너뜀")
            } else {
                logI("최상단으로 이동 중...")
                if let appName = detectedAppName {
                    if !scrollToTopAppleScript(appName: appName) {
                        logD("AppleScript scrollToTop 실패 → CGKey Home fallback")
                        scrollToTopCGKey()
                    }
                } else {
                    scrollToTopCGKey()
                }
                Thread.sleep(forTimeInterval: config.scrollDelay)
            }
        }

        var frames: [NSImage] = []

        // 첫 번째 프레임 캡처
        let firstRaw = try screenCapture.captureWindow(windowID: targetWindowID, options: options)
        let first = cropToScrollRegion(image: firstRaw, region: scrollRegion, windowBounds: bounds)
        frames.append(first)
        logI("스크롤 캡처 시작: 최대 \(config.maxScrolls)회 스크롤")

        // WebKit 앱 여부 판정 (첫 스크롤 시도에서 AppleScript 실패 시 false로 전환)
        var useAppleScript = (detectedAppName != nil)

        for i in 0..<config.maxScrolls {
            switch config.scrollMode {
            case .page:
                if useAppleScript, let appName = detectedAppName {
                    if !postPageDownAppleScript(appName: appName) {
                        logI("AppleScript PageDown 실패 → CGKey fallback 전환 ('\(appName)'은 WebKit 앱이 아님)")
                        useAppleScript = false
                        postPageDownCGKey()
                    }
                } else {
                    postPageDownCGKey()
                }
            case .scroll:
                if useAppleScript, let appName = detectedAppName {
                    if !postScrollEventAppleScript(appName: appName, amount: config.scrollAmount) {
                        logI("AppleScript Scroll 실패 → CGEvent fallback 전환")
                        useAppleScript = false
                        postScrollEvent(at: scrollPoint, amount: config.scrollAmount)
                    }
                } else {
                    postScrollEvent(at: scrollPoint, amount: config.scrollAmount)
                }
            }
            Thread.sleep(forTimeInterval: config.scrollDelay)

            let frameRaw = try screenCapture.captureWindow(windowID: targetWindowID, options: options)
            let frame = cropToScrollRegion(image: frameRaw, region: scrollRegion, windowBounds: bounds)

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

    // MARK: - Mouse Pointer Window Detection

    /// 현재 마우스 포인터 위치의 최상위 일반 윈도우 ID, 앱 이름, PID 반환
    private func windowAtMousePointer() -> (windowID: CGWindowID, ownerName: String, ownerPID: pid_t)? {
        let mouseLocation = NSEvent.mouseLocation
        guard let mainScreen = NSScreen.screens.first else { return nil }
        // NSEvent 좌표(좌하단 원점) → CGWindowList 좌표(좌상단 원점) 변환
        let cgMouseY = mainScreen.frame.height - mouseLocation.y
        let cgMousePoint = CGPoint(x: mouseLocation.x, y: cgMouseY)

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  !ownerName.isEmpty,
                  let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let wx = boundsDict["X"], let wy = boundsDict["Y"],
                  let ww = boundsDict["Width"], let wh = boundsDict["Height"] else { continue }

            // 시스템 UI 오버레이(layer != 0) 제외
            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 { continue }

            let windowRect = CGRect(x: wx, y: wy, width: ww, height: wh)
            if windowRect.contains(cgMousePoint) {
                return (windowID, ownerName, ownerPID)
            }
        }
        return nil
    }

    // MARK: - App Activation

    /// AppleScript로 지정 앱 활성화
    private func activateApp(_ appName: String) {
        let script = "tell application \"\(appName)\" to activate"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Scroll To Top

    /// AppleScript로 WebKit 앱 최상단 이동 (scrollMode 무관하게 JS window.scrollTo 사용)
    /// - Returns: AppleScript 실행 성공 여부 (exit code 0)
    @discardableResult
    private func scrollToTopAppleScript(appName: String) -> Bool {
        let script = """
        tell application "\(appName)"
            tell document 1
                do JavaScript "window.scrollTo(0, 0)"
            end tell
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    /// CGEvent로 Home 키 전송하여 최상단 이동 (Accessibility 권한 필요)
    private func scrollToTopCGKey() {
        let homeKeyCode: CGKeyCode = 115  // kVK_Home
        if let down = CGEvent(keyboardEventSource: nil, virtualKey: homeKeyCode, keyDown: true) {
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: nil, virtualKey: homeKeyCode, keyDown: false) {
            up.post(tap: .cghidEventTap)
        }
    }

    // MARK: - PageDown Methods

    /// AppleScript로 WebKit 앱 PageDown 효과 (window.innerHeight만큼 스크롤, Accessibility 불필요)
    /// - Returns: AppleScript 실행 성공 여부 (exit code 0)
    @discardableResult
    private func postPageDownAppleScript(appName: String) -> Bool {
        let script = """
        tell application "\(appName)"
            tell document 1
                do JavaScript "window.scrollBy(0, window.innerHeight)"
            end tell
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    /// CGEvent로 PageDown 키 전송 (Accessibility 권한 필요)
    private func postPageDownCGKey() {
        let pgDownKeyCode: CGKeyCode = 121  // kVK_PageDown
        if let down = CGEvent(keyboardEventSource: nil, virtualKey: pgDownKeyCode, keyDown: true) {
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: nil, virtualKey: pgDownKeyCode, keyDown: false) {
            up.post(tap: .cghidEventTap)
        }
    }

    // MARK: - AppleScript Scroll

    /// AppleScript로 앱 내 스크롤 (Accessibility 권한 불필요)
    /// Safari 등 WebKit 앱은 do JavaScript로 직접 스크롤
    /// - Returns: AppleScript 실행 성공 여부 (exit code 0)
    @discardableResult
    private func postScrollEventAppleScript(appName: String, amount: Int) -> Bool {
        let pixels = amount * 40  // 라인 단위 → 픽셀 변환
        let script = """
        tell application "\(appName)"
            tell document 1
                do JavaScript "window.scrollBy(0, \(pixels))"
            end tell
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    // MARK: - CGEvent Scroll

    /// CGEvent를 사용하여 스크롤 이벤트 전송 (양수: 아래로, 음수: 위로)
    /// 주의: Accessibility 권한 필요 (시스템 설정 → 개인정보 보호 → 손쉬운 사용)
    private func postScrollEvent(at point: CGPoint, amount: Int) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: Int32(-amount), // 음수 = 아래로 스크롤
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

    // MARK: - AX Scroll Area Detection

    /// AXUIElement로 마우스 위치의 스크롤 영역(AXScrollArea) 감지
    /// - Parameters:
    ///   - pid: 대상 앱의 프로세스 ID
    ///   - mousePoint: 마우스 위치 (CG 좌표계: 좌상단 원점)
    /// - Returns: (스크롤 영역 프레임, AXUIElement) 또는 nil (AX 미지원/권한 없음)
    func detectScrollAreaAX(pid: pid_t, mousePoint: CGPoint) -> (frame: CGRect, scrollArea: AXUIElement)? {
        let axApp = AXUIElementCreateApplication(pid)

        // 마우스 위치의 AX 요소 획득
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(axApp, Float(mousePoint.x), Float(mousePoint.y), &element)

        guard result == .success, let startElement = element else {
            logD("AX 요소 획득 실패 (pid=\(pid), point=\(mousePoint)): \(result.rawValue)")
            return nil
        }

        // 부모 체인 탐색 → 가장 깊은(첫 번째) AXScrollArea 선택
        guard let scrollArea = findScrollAreaAX(from: startElement) else {
            logD("AXScrollArea 미발견 (pid=\(pid))")
            return nil
        }

        // 프레임(위치 + 크기) 획득
        guard let frame = getAXFrame(scrollArea) else {
            logD("AXScrollArea 프레임 획득 실패")
            return nil
        }

        logI("AXScrollArea 감지: frame=\(frame)")
        return (frame, scrollArea)
    }

    /// 부모 체인을 탐색하여 가장 가까운 AXScrollArea 반환
    private func findScrollAreaAX(from element: AXUIElement) -> AXUIElement? {
        var current = element
        var depth = 0

        while depth < 30 {
            var role: CFTypeRef?
            if AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &role) == .success,
               let roleStr = role as? String, roleStr == "AXScrollArea" {
                return current
            }

            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success else {
                break
            }
            current = parent as! AXUIElement
            depth += 1
        }
        return nil
    }

    /// AXUIElement의 프레임(위치 + 크기) 반환
    private func getAXFrame(_ element: AXUIElement) -> CGRect? {
        var posValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(posValue as! AXValue, .cgPoint, &point) else { return nil }

        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }

        return CGRect(origin: point, size: size)
    }

    // MARK: - Scroll Region Resolution & Crop

    /// regionMode에 따라 스크롤 영역(스크린 좌표)을 결정
    /// - Returns: 크롭할 영역(스크린 좌표) 또는 nil (윈도우 전체)
    private func resolveScrollRegion(config: Config, windowBounds: CGRect, pid: pid_t?) -> CGRect? {
        switch config.regionMode {
        case .auto:
            // AX 감지 시도 → 실패 시 nil (window fallback)
            guard let pid = pid else {
                logD("PID 없음 → 스크롤 영역 감지 생략 (window fallback)")
                return nil
            }
            // 마우스 위치로 AX 감지
            let mouseLocation = NSEvent.mouseLocation
            guard let mainScreen = NSScreen.screens.first else { return nil }
            let cgMouseY = mainScreen.frame.height - mouseLocation.y
            let mousePoint = CGPoint(x: mouseLocation.x, y: cgMouseY)

            if let (frame, _) = detectScrollAreaAX(pid: pid, mousePoint: mousePoint) {
                return frame
            }
            logD("AX 스크롤 영역 미감지 → window fallback")
            return nil

        case .rect:
            // 수동 지정 영역 → 윈도우 좌상단 기준 → 스크린 좌표 변환
            guard let rect = config.region else {
                logW("regionMode=rect 이지만 region 미지정 → window fallback")
                return nil
            }
            let screenRect = CGRect(
                x: windowBounds.origin.x + rect.origin.x,
                y: windowBounds.origin.y + rect.origin.y,
                width: rect.width,
                height: rect.height
            )
            return screenRect

        case .window:
            return nil
        }
    }

    /// 캡처된 윈도우 이미지를 스크롤 영역으로 크롭
    /// - Parameters:
    ///   - image: 윈도우 전체 캡처 이미지
    ///   - region: 스크롤 영역 (스크린 좌표) 또는 nil (크롭 안 함)
    ///   - windowBounds: 윈도우 위치 (스크린 좌표)
    /// - Returns: 크롭된 이미지 또는 원본
    private func cropToScrollRegion(image: NSImage, region: CGRect?, windowBounds: CGRect) -> NSImage {
        guard let region = region else { return image }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }

        // 스크린 좌표 → 윈도우 내 상대좌표
        let relativeX = region.origin.x - windowBounds.origin.x
        let relativeY = region.origin.y - windowBounds.origin.y

        // backingScaleFactor 적용 (논리 px → 물리 px)
        let scale = screenBackingScaleFactor(for: region)
        let cropRect = CGRect(
            x: relativeX * scale,
            y: relativeY * scale,
            width: region.width * scale,
            height: region.height * scale
        )

        // CGImage 좌표계: y=0이 상단 (top-down)
        guard let cropped = cgImage.cropping(to: cropRect) else {
            logW("스크롤 영역 크롭 실패: cropRect=\(cropRect), imageSize=\(cgImage.width)x\(cgImage.height)")
            return image
        }

        return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
    }

    /// 지정 영역이 위치한 스크린의 backingScaleFactor 반환
    private func screenBackingScaleFactor(for rect: CGRect) -> CGFloat {
        for screen in NSScreen.screens {
            if screen.frame.intersects(rect) {
                return screen.backingScaleFactor
            }
        }
        return NSScreen.main?.backingScaleFactor ?? 1.0
    }

    // MARK: - Scroll End Detection

    /// 현재 프레임과 이전 프레임의 중앙 60% 픽셀을 샘플링하여 스크롤 끝 여부 판단
    private func isScrollEnd(current: NSImage, previous: NSImage) -> Bool {
        guard let curCG = current.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let preCG = previous.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }

        let h = curCG.height
        let w = curCG.width
        let sampleW = min(w / 2, 400)       // 이미지 중앙에서 가로 샘플
        let startX = (w - sampleW) / 2      // 수평 중앙
        let sampleH = max(20, h * 2 / 5)   // 중앙 40% 높이
        let startY = h * 3 / 10            // 아래쪽 30% 위치 (CG좌표: 하단 기준)

        logD("isScrollEnd 샘플 영역: x=\(startX) y=\(startY) \(sampleW)x\(sampleH) (이미지: \(w)x\(h))")

        guard let curPixels = extractPixels(from: curCG, x: startX, y: startY, width: sampleW, height: sampleH),
              let prePixels = extractPixels(from: preCG, x: startX, y: startY, width: sampleW, height: sampleH) else { return false }

        var totalDiff: Int = 0
        let count = min(curPixels.count, prePixels.count)
        for i in 0..<count {
            totalDiff += abs(Int(curPixels[i]) - Int(prePixels[i]))
        }
        let avgDiff = Double(totalDiff) / Double(max(1, count))
        logD("스크롤 끝 감지 픽셀 diff: \(String(format: "%.2f", avgDiff)) (임계값 3.0)")
        return avgDiff < 3.0
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

        // 각 프레임 간 오버랩 높이(픽셀) 계산
        var overlapHeights: [Int] = []
        for i in 1..<frames.count {
            let overlap = findOverlapHeight(
                previous: frames[i - 1],
                current: frames[i],
                maxRatio: overlapRatio
            )
            overlapHeights.append(overlap)
        }

        // 총 출력 높이 계산
        var totalHeight = frameH
        for i in 0..<overlapHeights.count {
            guard let cgImg = frames[i + 1].cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            totalHeight += cgImg.height - overlapHeights[i]
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

        // CoreGraphics: Y=0이 하단. 첫 프레임을 최상단에 배치
        // 첫 프레임: Y = totalHeight - frameH
        var currentY = totalHeight

        for (index, frame) in frames.enumerated() {
            guard let cgImg = frame.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            let imgH = cgImg.height
            let skipTop = (index == 0) ? 0 : overlapHeights[index - 1]
            let drawH = imgH - skipTop

            if drawH <= 0 { continue }

            currentY -= drawH
            let destRect = CGRect(x: 0, y: currentY, width: frameW, height: drawH)

            if skipTop > 0 {
                // 상단 skipTop 픽셀 제거 (오버랩 영역):
                // CGImage.cropping Y: y=0이 이미지 상단 (top-down) → y=skipTop부터 잘라내기
                let cropRect = CGRect(x: 0, y: skipTop, width: frameW, height: imgH - skipTop)
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

    // MARK: - Overlap Detection (Vision + 픽셀 fallback)

    /// Apple Vision Framework로 두 프레임 간 수직 오프셋을 계산하여 오버랩 높이(픽셀) 반환
    /// Vision 실패 시 기존 픽셀 비교 방식으로 fallback
    private func findOverlapHeight(previous: NSImage, current: NSImage, maxRatio: Double) -> Int {
        guard let preCG = previous.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let curCG = current.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 0 }

        let maxOverlap = Int(Double(curCG.height) * maxRatio)

        // 1단계: Vision으로 오프셋 계산 시도
        if let visionOverlap = findOverlapVision(currentCG: curCG, previousCG: preCG, currentImage: current, maxOverlap: maxOverlap) {
            return visionOverlap
        }

        // 2단계: Vision 실패 시 픽셀 비교 fallback
        logI("Vision fallback → 픽셀 비교 방식으로 오버랩 탐색")
        return findOverlapPixel(previousCG: preCG, currentCG: curCG, maxOverlap: maxOverlap)
    }

    /// Vision 기반 오버랩 탐색
    private func findOverlapVision(currentCG: CGImage, previousCG: CGImage, currentImage: NSImage, maxOverlap: Int) -> Int? {
        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: previousCG)
        let handler = VNImageRequestHandler(cgImage: currentCG, options: [:])

        do {
            try handler.perform([request])
        } catch {
            logD("Vision 오프셋 계산 실패: \(error.localizedDescription)")
            return nil
        }

        guard let observation = request.results?.first as? VNImageTranslationAlignmentObservation else {
            logD("Vision 정합 결과 없음")
            return nil
        }

        let ty = observation.alignmentTransform.ty

        // ty <= 0: 역방향 또는 이동 없음 → Vision 오판
        if ty <= 0 {
            logD("Vision ty=\(String(format: "%.1f", ty)) (역방향) → fallback")
            return nil
        }

        // 포인트 → 픽셀 변환
        let scale: CGFloat = currentImage.size.height > 0
            ? CGFloat(currentCG.height) / currentImage.size.height
            : 1.0
        let offsetPixels = ty * scale
        let overlapHeight = Int(CGFloat(currentCG.height) - offsetPixels)

        logD("Vision 오버랩: ty=\(String(format: "%.1f", ty))pt, offset=\(String(format: "%.0f", offsetPixels))px, overlap=\(overlapHeight)px (프레임=\(currentCG.height)px)")

        // 범위 검증: 0 < overlap < maxOverlap
        if overlapHeight <= 0 || overlapHeight > maxOverlap {
            logD("Vision 오버랩 범위 초과: \(overlapHeight)px (max=\(maxOverlap)) → fallback")
            return nil
        }

        return overlapHeight
    }

    /// 픽셀 비교 기반 오버랩 탐색 (fallback)
    /// 이전 프레임 하단 vs 현재 프레임 상단을 행 단위로 비교
    private func findOverlapPixel(previousCG: CGImage, currentCG: CGImage, maxOverlap: Int) -> Int {
        let h = previousCG.height
        let cw = min(previousCG.width / 2, 400)
        let cx = (previousCG.width - cw) / 2
        let sampleRows = 5

        var bestOverlap = 0
        var bestScore = Double.greatestFiniteMagnitude

        for overlap in stride(from: maxOverlap, through: 10, by: -2) {
            let preStartY = max(0, h - overlap)
            let curStartY = 0

            let preHeight = min(sampleRows, h - preStartY)
            let curHeight = min(sampleRows, currentCG.height)

            guard preHeight > 0, curHeight > 0,
                  let preRows = extractPixels(from: previousCG, x: cx, y: preStartY, width: cw, height: preHeight),
                  let curRows = extractPixels(from: currentCG, x: cx, y: curStartY, width: cw, height: curHeight) else {
                continue
            }

            var totalDiff = 0
            let count = min(preRows.count, curRows.count)
            for i in 0..<count {
                totalDiff += abs(Int(preRows[i]) - Int(curRows[i]))
            }
            let avgDiff = Double(totalDiff) / Double(max(1, count))

            if avgDiff < bestScore {
                bestScore = avgDiff
                bestOverlap = overlap
            }

            // 매우 낮은 diff → 확실한 매칭
            if avgDiff < 2.0 { break }
        }

        if bestScore < 10.0 {
            logD("픽셀 오버랩: overlap=\(bestOverlap)px, score=\(String(format: "%.2f", bestScore))")
            return bestOverlap
        }

        logD("픽셀 오버랩 탐색 실패: bestScore=\(String(format: "%.2f", bestScore))")
        return 0
    }

    // MARK: - Pixel Extraction

    /// CGImage에서 지정 영역의 픽셀 데이터(RGBA) 추출
    /// - Note: CG 좌표계 — y=0이 이미지 하단
    private func extractPixels(from cgImage: CGImage, x: Int, y: Int, width: Int, height: Int) -> [UInt8]? {
        guard width > 0, height > 0 else { return nil }

        // CGImage.cropping으로 서브이미지 추출 (CG 좌표계: y=0 하단)
        let cropRect = CGRect(x: x, y: y, width: width, height: height)
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }

        let bytesPerPixel = 4
        var data = [UInt8](repeating: 0, count: cropped.width * cropped.height * bytesPerPixel)

        // 호환성 높은 포맷: nativeByteOrder + premultipliedFirst (macOS CGWindowListCreateImage 기본)
        guard let ctx = CGContext(
            data: &data,
            width: cropped.width,
            height: cropped.height,
            bitsPerComponent: 8,
            bytesPerRow: cropped.width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))
        return data
    }
}

import Foundation
import CoreGraphics
import AppKit

/// 스크린샷 캡처를 위한 독립 모듈
public class ScreenCapture {
    
    // MARK: - Error Types
    public enum ScreenCaptureError: Error, LocalizedError {
        case captureFailure(String)
        case saveFailure(String)
        case permissionDenied
        
        public var errorDescription: String? {
            switch self {
            case .captureFailure(let message):
                return "캡처 실패: \(message)"
            case .saveFailure(let message):
                return "저장 실패: \(message)"
            case .permissionDenied:
                return "스크린 캡처 권한이 필요합니다"
            }
        }
    }
    
    // MARK: - Capture Options
    public struct CaptureOptions {
        public let includeWindowShadow: Bool
        public let captureMouseCursor: Bool
        public let imageFormat: ImageFormat
        public let quality: Float // 0.0 ~ 1.0
        
        public init(
            includeWindowShadow: Bool = false,
            captureMouseCursor: Bool = false,
            imageFormat: ImageFormat = .png,
            quality: Float = 1.0
        ) {
            self.includeWindowShadow = includeWindowShadow
            self.captureMouseCursor = captureMouseCursor
            self.imageFormat = imageFormat
            self.quality = max(0.0, min(1.0, quality))
        }
    }
    
    public enum ImageFormat {
        case png
        case jpeg
        case tiff
        
        var fileExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            case .tiff: return "tiff"
            }
        }
    }
    
    // MARK: - Initialization
    public init() {}
    
    // MARK: - Full Screen Capture
    /// 전체 화면을 캡처합니다
    public func captureFullScreen(options: CaptureOptions = CaptureOptions()) throws -> NSImage {
        guard let mainDisplay = CGMainDisplayID() as CGDirectDisplayID?,
              let cgImage = CGDisplayCreateImage(mainDisplay) else {
            throw ScreenCaptureError.captureFailure("메인 디스플레이 캡처에 실패했습니다")
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
    }
    
    /// 특정 디스플레이를 캡처합니다 (screen:1, screen:2, screen:3 등)
    public func captureDisplay(displayNumber: Int, options: CaptureOptions = CaptureOptions()) throws -> NSImage {
        // 사용 가능한 모든 디스플레이 가져오기
        let maxDisplays: UInt32 = 32
        var displayCount: UInt32 = 0
        var displays = Array<CGDirectDisplayID>(repeating: 0, count: Int(maxDisplays))
        
        guard CGGetActiveDisplayList(maxDisplays, &displays, &displayCount) == CGError.success else {
            throw ScreenCaptureError.captureFailure("디스플레이 목록을 가져올 수 없습니다")
        }
        
        // 요청된 디스플레이 번호가 유효한지 확인
        guard displayNumber > 0 && displayNumber <= displayCount else {
            throw ScreenCaptureError.captureFailure("디스플레이 \(displayNumber)이(가) 존재하지 않습니다. 사용 가능한 디스플레이: 1-\(displayCount)")
        }
        
        let targetDisplay = displays[displayNumber - 1] // 0-based index
        
        guard let cgImage = CGDisplayCreateImage(targetDisplay) else {
            throw ScreenCaptureError.captureFailure("디스플레이 \(displayNumber) 캡처에 실패했습니다")
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
    }
    
    /// 사용 가능한 디스플레이 정보를 가져옵니다
    public func getAvailableDisplays() -> [(displayNumber: Int, bounds: CGRect, isMain: Bool)] {
        let maxDisplays: UInt32 = 32
        var displayCount: UInt32 = 0
        var displays = Array<CGDirectDisplayID>(repeating: 0, count: Int(maxDisplays))
        
        guard CGGetActiveDisplayList(maxDisplays, &displays, &displayCount) == CGError.success else {
            return []
        }
        
        let mainDisplayID = CGMainDisplayID()
        var displayInfo: [(Int, CGRect, Bool)] = []
        
        for i in 0..<Int(displayCount) {
            let display = displays[i]
            let bounds = CGDisplayBounds(display)
            let isMain = (display == mainDisplayID)
            displayInfo.append((i + 1, bounds, isMain)) // 1-based numbering
        }
        
        return displayInfo
    }
    
    // MARK: - Window Capture
    /// 특정 윈도우를 캡처합니다
    public func captureWindow(windowID: CGWindowID, options: CaptureOptions = CaptureOptions()) throws -> NSImage {
        let windowListOption: CGWindowListOption = options.includeWindowShadow ? 
            [.optionIncludingWindow] : [.optionIncludingWindow, .excludeDesktopElements]
        
        guard let cgImage = CGWindowListCreateImage(
            .null,
            windowListOption,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            throw ScreenCaptureError.captureFailure("윈도우 캡처에 실패했습니다")
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
    }
    
    // MARK: - Region Capture
    /// 특정 영역을 캡처합니다
    public func captureRegion(_ rect: CGRect, options: CaptureOptions = CaptureOptions()) throws -> NSImage {
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            throw ScreenCaptureError.captureFailure("영역 캡처에 실패했습니다")
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
    }
    
    // MARK: - Save Functions
    /// NSImage를 파일로 저장합니다
    public func saveImage(_ image: NSImage, to url: URL, options: CaptureOptions = CaptureOptions()) throws {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ScreenCaptureError.saveFailure("이미지 변환에 실패했습니다")
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        
        let data: Data?
        switch options.imageFormat {
        case .png:
            data = bitmapRep.representation(using: .png, properties: [:])
        case .jpeg:
            data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: options.quality])
        case .tiff:
            data = bitmapRep.representation(using: .tiff, properties: [:])
        }
        
        guard let imageData = data else {
            throw ScreenCaptureError.saveFailure("이미지 데이터 생성에 실패했습니다")
        }
        
        do {
            try imageData.write(to: url)
        } catch {
            throw ScreenCaptureError.saveFailure("파일 저장에 실패했습니다: \(error.localizedDescription)")
        }
    }
    
    /// 빠른 저장 - 파일명 자동 생성
    public func quickSave(_ image: NSImage, to directory: URL, options: CaptureOptions = CaptureOptions()) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let filename = "screenshot_\(timestamp).\(options.imageFormat.fileExtension)"
        let fileURL = directory.appendingPathComponent(filename)
        
        try saveImage(image, to: fileURL, options: options)
        return fileURL
    }
    
    // MARK: - Utility Functions
    /// 사용 가능한 모든 윈도우 목록을 가져옵니다
    public func getAvailableWindows() -> [(windowID: CGWindowID, name: String, ownerName: String)] {
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        var windows: [(CGWindowID, String, String)] = []
        
        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  !ownerName.isEmpty else {
                continue
            }
            let windowName = windowInfo[kCGWindowName as String] as? String ?? ""

            windows.append((windowID, windowName, ownerName))
        }
        
        return windows
    }
    
    /// 현재 화면 최상단 일반 앱 윈도우 ID를 반환 (layer == 0, alpha > 0)
    /// CGWindowListCopyWindowInfo는 front-to-back 순서로 반환하므로 첫 번째가 frontmost
    public func getFrontmostWindowID() -> CGWindowID? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }
        for windowInfo in windowList {
            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? Int.max
            let alpha = windowInfo[kCGWindowAlpha as String] as? Double ?? 0
            guard layer == 0, alpha > 0 else { continue }
            if let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID {
                return windowID
            }
        }
        return nil
    }

    /// 스크린 권한 체크
    public func checkScreenRecordingPermission() -> Bool {
        let stream = CGDisplayStream(
            dispatchQueueDisplay: CGMainDisplayID(),
            outputWidth: 1,
            outputHeight: 1,
            pixelFormat: Int32(kCVPixelFormatType_32BGRA),
            properties: nil,
            queue: DispatchQueue.global()
        ) { _, _, _, _ in }
        
        return stream != nil
    }
}
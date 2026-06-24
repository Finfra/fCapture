import Foundation
import AppKit

// MARK: - State Management
class StateManager {
    static let shared = StateManager()
    private let stateFileURL: URL
    
    struct ScreenshotState: Codable {
        let fileName: String
        let timestamp: Date
        let date: String
        let id: Int
    }
    
    struct RegionBounds: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    struct StateData: Codable {
        let lastScreenshot: ScreenshotState
        let defaultResultFormat: String?
        let lastRegion: RegionBounds?
    }
    
    private init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let fCaptureDir = homeDir.appendingPathComponent(".fCapture")
        stateFileURL = fCaptureDir.appendingPathComponent("info_stateManager.json")
        
        // .fCapture 디렉토리 생성
        try? FileManager.default.createDirectory(at: fCaptureDir, withIntermediateDirectories: true)
    }
    
    func getNextID() -> Int {
        guard let lastState = loadLastState() else {
            // 첫 번째 스크린샷
            return 1
        }

        let currentDate = getCurrentDateString()
        
        // 3시간 + 날짜 변경 체크
        if shouldResetID(lastTimestamp: lastState.timestamp, lastDate: lastState.date, currentDate: currentDate) {
            return 1
        } else {
            return lastState.id + 1
        }
    }
    
    func updateState(fileName: String, id: Int, logOutput: Bool = true) {
        let now = Date()
        let currentDate = getCurrentDateString()

        let newState = ScreenshotState(
            fileName: fileName,
            timestamp: now,
            date: currentDate,
            id: id
        )

        // 기존 설정 보존하면서 업데이트
        let existingData = loadStateData()
        let existingFormat = existingData?.defaultResultFormat
        let existingRegion = existingData?.lastRegion
        let stateData = StateData(
            lastScreenshot: newState,
            defaultResultFormat: existingFormat ?? "text",
            lastRegion: existingRegion
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(stateData)
            try data.write(to: stateFileURL)
            if logOutput {
                logI("상태 파일 업데이트: ID=\(id), 파일=\(fileName)")
            }
        } catch {
            if logOutput {
                logE("상태 파일 저장 실패: \(error.localizedDescription)")
            }
        }
    }
    
    func getDefaultResultFormat() -> ScreenCaptureConfig.ResultFormat {
        if let stateData = loadStateData(),
           let formatString = stateData.defaultResultFormat,
           let format = ScreenCaptureConfig.ResultFormat(rawValue: formatString) {
            return format
        }
        return .text // 기본값
    }
    
    func setDefaultResultFormat(_ format: ScreenCaptureConfig.ResultFormat, logOutput: Bool = true) {
        // 현재 상태 로드
        if let currentState = loadLastState() {
            let existingRegion = loadStateData()?.lastRegion
            let stateData = StateData(
                lastScreenshot: currentState,
                defaultResultFormat: format.rawValue,
                lastRegion: existingRegion
            )

            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(stateData)
                try data.write(to: stateFileURL)
                if logOutput {
                    logI("기본 결과 형식 설정: \(format.rawValue)")
                }
            } catch {
                if logOutput {
                    logE("결과 형식 설정 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadLastState() -> ScreenshotState? {
        return loadStateData()?.lastScreenshot
    }
    
    private func loadStateData() -> StateData? {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: stateFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let stateData = try decoder.decode(StateData.self, from: data)
            return stateData
        } catch {
            logW("상태 파일 읽기 실패: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func shouldResetID(lastTimestamp: Date, lastDate: String, currentDate: String) -> Bool {
        let now = Date()
        let timeDiff = now.timeIntervalSince(lastTimestamp)
        let threeHours: TimeInterval = 3 * 60 * 60
        
        return timeDiff > threeHours && lastDate != currentDate
    }
    
    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }

    func saveLastRegion(_ bounds: RegionBounds, logOutput: Bool = true) {
        if let currentState = loadLastState() {
            let existingFormat = loadStateData()?.defaultResultFormat
            let stateData = StateData(
                lastScreenshot: currentState,
                defaultResultFormat: existingFormat,
                lastRegion: bounds
            )
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(stateData)
                try data.write(to: stateFileURL)
                if logOutput {
                    logI("영역 좌표 저장: x=\(bounds.x), y=\(bounds.y), width=\(bounds.width), height=\(bounds.height)")
                }
            } catch {
                if logOutput {
                    logE("영역 좌표 저장 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    func getLastRegion() -> RegionBounds? {
        return loadStateData()?.lastRegion
    }
}

// MARK: - Logging System
class Logger {
    static let shared = Logger()
    private let logFileURL = URL(fileURLWithPath: "/tmp/fCapture.log")
    private let dateFormatter: DateFormatter
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    func log(_ message: String, level: String = "INFO") {
        let timestamp = dateFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] [\(level)] \(message)\n"

        // 콘솔 출력 (stderr)
        fputs(message + "\n", stderr)

        // 파일 출력
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                // 파일이 있으면 추가
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // 파일이 없으면 생성
                try? data.write(to: logFileURL)
            }
        }
    }

    func logV(_ message: String) { log(message, level: "VERBOSE") }
    func logD(_ message: String) { log(message, level: "DEBUG") }
    func logI(_ message: String) { log(message, level: "INFO") }
    func logW(_ message: String) { log(message, level: "WARN") }
    func logE(_ message: String) { log(message, level: "ERROR") }
    func logC(_ message: String) { log(message, level: "CRITICAL") }
}

// MARK: - Global Log Functions

let logger = Logger.shared

func logV(_ message: @autoclosure () -> String, file: String = #file) { logger.logV(message()) }
func logD(_ message: @autoclosure () -> String, file: String = #file) { logger.logD(message()) }
func logI(_ message: @autoclosure () -> String, file: String = #file) { logger.logI(message()) }
func logW(_ message: @autoclosure () -> String, file: String = #file) { logger.logW(message()) }
func logE(_ message: @autoclosure () -> String, file: String = #file) { logger.logE(message()) }
func logC(_ message: @autoclosure () -> String, file: String = #file) { logger.logC(message()) }

// MARK: - Capture Result
struct CaptureResult: Codable {
    let filePath: String
    let fileName: String
    let target: String
    let id: Int
}

// MARK: - Configuration Structure
struct ScreenCaptureConfig: Codable {
    var capturePath: CapturePathType?
    var capturePathArray: [String]?
    var target: TargetType?
    var fileFormat: String?
    var staticRegion: StaticRegionConfig?
    var result: ResultFormat?
    var backupOtherScreen: String?
    var shadow: Bool?
    var windowFlash: Bool?
    var scrollConfig: ScrollConfig?
    var relay: Double?  // 캡처 N초 지연 후 실행 (CLI --relay 와 동일, 설정 파일 지정용)

    enum CodingKeys: String, CodingKey {
        case capturePath, capturePathArray, target, fileFormat, staticRegion, result, backupOtherScreen, shadow
        case windowFlash = "window_flash"
        case scrollConfig, relay
    }

    static let defaultConfig = ScreenCaptureConfig(
        capturePath: nil,
        capturePathArray: nil,
        target: nil,
        fileFormat: nil,
        staticRegion: nil,
        result: nil,
        backupOtherScreen: nil,
        shadow: nil,
        windowFlash: nil,
        scrollConfig: nil,
        relay: nil
    )
    
    enum CapturePathType: Codable {
        case string(String)
        case index(Int)
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
            } else if let intValue = try? container.decode(Int.self) {
                self = .index(intValue)
            } else {
                throw DecodingError.typeMismatch(CapturePathType.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Int"))
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value):
                try container.encode(value)
            case .index(let value):
                try container.encode(value)
            }
        }
    }
    
    struct StaticRegionConfig: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double

        var cgRect: CGRect {
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }

    struct ScrollConfig: Codable {
        let scrollAmount: Int?    // 스크롤 라인 단위 (기본 8)
        let scrollDelay: Double?  // 스크롤 후 대기 시간(초, 기본 0.5)
        let maxScrolls: Int?      // 최대 스크롤 횟수 (기본 30)
        let overlapRatio: Double? // 오버랩 탐색 범위 비율 (기본 0.25)
        let scrollMode: String?   // 스크롤 방식: "page"(기본, PageDown키) / "scroll"(마우스스크롤)
        let scrollToTop: Bool?    // 캡처 시작 전 최상단 이동 여부 (기본 true)
        let excludeApps: [String]? // scrollToTop 건너뛸 예외 앱 목록 (기본 ["iTerm2", "Terminal"])
        let targetApp: String?    // 명시적 타겟 앱 이름 (미지정 시 마우스 포인터 자동 감지)
        let regionMode: String?   // 영역 모드: "auto"(기본, AX감지) / "rect"(수동지정) / "window"(윈도우전체)
        let region: RegionRect?   // regionMode: "rect"일 때 사용할 영역 (윈도우 좌상단 기준, 논리 px)
    }

    struct RegionRect: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }
    
    enum ResultFormat: String, Codable {
        case text = "text"
        case json = "json"
        case onlyPath = "onlyPath"
    }
    
    enum TargetType: Codable {
        case single(String)
        case multiple([String])
        case all
        case staticRegion
        case region
        case scrollCapture

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
                    self = .scrollCapture
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
            case .single(let value):
                try container.encode(value)
            case .multiple(let values):
                try container.encode(values)
            case .all:
                try container.encode("all")
            case .staticRegion:
                try container.encode("staticRegion")
            case .region:
                try container.encode("region")
            case .scrollCapture:
                try container.encode("scroll_capture")
            }
        }
    }
}

// MARK: - CLI Argument Parsing
struct CLIOverrides {
    var targets: [String] = []
    var capturePath: String? = nil
    var fileFormat: String? = nil
    var shadow: Bool? = nil
    var windowFlash: Bool? = nil
    var result: String? = nil
    var region: String? = nil
    var backupPath: String? = nil
    var scrollMode: String? = nil  // "--scroll" 플래그 → "scroll" (기본: "page")
    var scrollRegionMode: String? = nil   // "--region auto|rect|window"
    var scrollRegionRect: String? = nil   // "--region-rect x,y,w,h"
    var relay: Double? = nil  // "--relay N" → 캡처 N초 지연 후 실행
}

// MARK: - CLI Main Function
@main
struct ScreenCaptureApp {
    static let appVersion = "1.0.18"

    /// CLI 인자를 파싱하여 (configFile, presetFlag, overrides)를 반환합니다.
    /// - parameters args: CommandLine.arguments
    /// - returns: (configFile: 경로or nil, presetFlag: "-s"/"-w"/"-r"/"-f"/"-h"or nil, overrides: CLIOverrides)
    static func parseArguments(_ args: [String]) -> (configFile: String?, presetFlag: String?, overrides: CLIOverrides) {
        var configFile: String? = nil
        var presetFlag: String? = nil
        var overrides = CLIOverrides()

        var i = 1
        while i < args.count {
            let arg = args[i]

            // 프리셋 플래그 (우선 순위 최고, 나머지도 파싱)
            // 주의: -r/--region은 프리셋이 아니라 --region <x,y,w,h> 옵션으로만 처리됨
            if arg == "-v" || arg == "--version" {
                presetFlag = arg
                i += 1
                continue
            }
            if arg == "-h" || arg == "--help" {
                presetFlag = arg
                i += 1
                continue
            }
            if arg == "-s" || arg == "--screen" {
                presetFlag = arg
                i += 1
                continue
            }
            if arg == "-w" || arg == "--window" {
                presetFlag = arg
                i += 1
                continue
            }
            if arg == "-f" || arg == "--fixRegion" {
                presetFlag = arg
                i += 1
                continue
            }
            if arg == "-r" {
                presetFlag = arg
                i += 1
                continue
            }

            // 타겟 옵션 (반복 가능)
            if arg == "-t" || arg == "--target" {
                i += 1
                if i < args.count {
                    overrides.targets.append(args[i])
                }
                i += 1
                continue
            }

            // 캡처 경로
            if arg == "-p" || arg == "--path" {
                i += 1
                if i < args.count {
                    overrides.capturePath = args[i]
                }
                i += 1
                continue
            }

            // 파일 형식
            if arg == "-F" || arg == "--format" {
                i += 1
                if i < args.count {
                    overrides.fileFormat = args[i]
                }
                i += 1
                continue
            }

            // 그림자 옵션
            if arg == "--shadow" {
                overrides.shadow = true
                i += 1
                continue
            }
            if arg == "--no-shadow" {
                overrides.shadow = false
                i += 1
                continue
            }

            // 윈도우 플래시 옵션
            if arg == "--flash" {
                overrides.windowFlash = true
                i += 1
                continue
            }
            if arg == "--no-flash" {
                overrides.windowFlash = false
                i += 1
                continue
            }

            // 결과 형식
            if arg == "-R" || arg == "--result" {
                i += 1
                if i < args.count {
                    let resultValue = args[i]
                    if !["text", "json", "onlyPath"].contains(resultValue) {
                        let errorMessage = "잘못된 결과 형식: \(resultValue) (text, json, onlyPath 중 하나)"
                        logE(errorMessage)
                        exit(1)
                    }
                    overrides.result = resultValue
                }
                i += 1
                continue
            }

            // 정적 영역 (<x,y,w,h> 형식)
            if arg == "--region" {
                i += 1
                if i < args.count {
                    let regionStr = args[i]
                    // 좌표 형식 유효성 검증
                    let components = regionStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                    if components.count != 4 {
                        let errorMessage = "잘못된 --region 형식: \(regionStr) (올바른 형식: x,y,width,height)"
                        logE(errorMessage)
                        exit(1)
                    }
                    overrides.region = regionStr
                }
                i += 1
                continue
            }

            // 백업 경로
            if arg == "--backup" || arg == "--backupOtherScreen" {
                i += 1
                if i < args.count {
                    overrides.backupPath = args[i]
                }
                i += 1
                continue
            }

            // 스크롤 방식 (--scroll: 마우스스크롤 방식, 기본은 PageDown 방식)
            if arg == "--scroll" {
                overrides.scrollMode = "scroll"
                i += 1
                continue
            }

            // 스크롤 영역 모드 (--scroll-region auto|rect|window)
            if arg == "--scroll-region" {
                i += 1
                if i < args.count {
                    overrides.scrollRegionMode = args[i]
                }
                i += 1
                continue
            }

            // 스크롤 영역 수동 지정 (--scroll-region-rect "x,y,w,h")
            if arg == "--scroll-region-rect" {
                i += 1
                if i < args.count {
                    overrides.scrollRegionRect = args[i]
                }
                i += 1
                continue
            }

            // 지연 캡처 (--relay N: 캡처를 N초 지연 후 실행)
            if arg == "--relay" {
                i += 1
                if i < args.count {
                    let relayStr = args[i]
                    guard let relayValue = Double(relayStr), relayValue >= 0 else {
                        logE("잘못된 --relay 값: \(relayStr) (0 이상의 숫자, 단위: 초)")
                        exit(1)
                    }
                    overrides.relay = relayValue
                } else {
                    logE("--relay 옵션에 지연 시간(초)이 필요합니다")
                    exit(1)
                }
                i += 1
                continue
            }

            // 알 수 없는 옵션 처리 (- 로 시작하는 것)
            if arg.hasPrefix("-") {
                let errorMessage = "알 수 없는 옵션: \(arg)"
                logE(errorMessage)
                exit(1)
            }

            // 설정 파일 판별 (첫 번째 비옵션 인수)
            if configFile == nil {
                if arg.hasSuffix(".json") || arg.contains("/") || arg.hasPrefix("~") {
                    // 경로 확장 처리 (~가 포함된 경우)
                    var expandedPath = arg
                    if arg.hasPrefix("~") {
                        expandedPath = NSString(string: arg).expandingTildeInPath
                    }

                    // 파일 존재 여부 확인
                    if !FileManager.default.fileExists(atPath: expandedPath) {
                        let errorMessage = "설정 파일을 찾을 수 없습니다: \(arg)"
                        logE(errorMessage)
                        exit(1)
                    }
                    configFile = expandedPath
                } else if FileManager.default.fileExists(atPath: arg) {
                    configFile = arg
                } else {
                    let errorMessage = "파일을 찾을 수 없습니다: \(arg)"
                    logE(errorMessage)
                    exit(1)
                }
            }

            i += 1
        }

        return (configFile: configFile, presetFlag: presetFlag, overrides: overrides)
    }

    /// CLI 옵션으로 base config를 오버라이드합니다.
    static func mergeConfig(base: ScreenCaptureConfig, overrides: CLIOverrides) -> ScreenCaptureConfig {
        var merged = base

        // 타겟 오버라이드
        if !overrides.targets.isEmpty {
            if overrides.targets.count == 1 {
                let value = overrides.targets[0]
                if let parsedTarget = parseTargetType(value) {
                    merged.target = parsedTarget
                } else {
                    // 유효하지 않은 target 값
                    logE("유효하지 않은 target 값: \(value)")
                    exit(1)
                }
            } else {
                merged.target = .multiple(overrides.targets)
            }
        }

        // 캡처 경로 오버라이드
        if let path = overrides.capturePath {
            merged.capturePath = .string(path)
        }

        // 파일 형식 오버라이드
        if let format = overrides.fileFormat {
            merged.fileFormat = format
        }

        // 그림자 오버라이드
        if let shadow = overrides.shadow {
            merged.shadow = shadow
        }

        // 윈도우 플래시 오버라이드
        if let flash = overrides.windowFlash {
            merged.windowFlash = flash
        }

        // 결과 형식 오버라이드
        if let resultStr = overrides.result {
            if let resultFormat = ScreenCaptureConfig.ResultFormat(rawValue: resultStr) {
                merged.result = resultFormat
            }
        }

        // 정적 영역 오버라이드 (--region <x,y,w,h> 옵션)
        if let regionStr = overrides.region {
            let components = regionStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if components.count == 4 {
                merged.staticRegion = ScreenCaptureConfig.StaticRegionConfig(x: components[0], y: components[1], width: components[2], height: components[3])
                // --region 옵션이 있으면 자동으로 region_static 타겟 설정
                if overrides.targets.isEmpty {
                    merged.target = .staticRegion
                }
            } else {
                let errorMessage = "잘못된 --region 형식: \(regionStr) (올바른 형식: x,y,width,height)"
                logE(errorMessage)
                exit(1)
            }
        }

        // 백업 경로 오버라이드
        if let backupPath = overrides.backupPath {
            merged.backupOtherScreen = backupPath
        }

        // 스크롤 관련 오버라이드 (--scroll, --scroll-region, --scroll-region-rect)
        if overrides.scrollMode != nil || overrides.scrollRegionMode != nil || overrides.scrollRegionRect != nil {
            let sc = merged.scrollConfig

            // --scroll-region-rect 파싱
            var regionRect: ScreenCaptureConfig.RegionRect? = sc?.region
            if let rectStr = overrides.scrollRegionRect {
                let parts = rectStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                if parts.count == 4 {
                    regionRect = ScreenCaptureConfig.RegionRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
                } else {
                    logE("잘못된 --scroll-region-rect 형식: \(rectStr) (올바른 형식: x,y,w,h)")
                    exit(1)
                }
            }

            merged.scrollConfig = ScreenCaptureConfig.ScrollConfig(
                scrollAmount: sc?.scrollAmount,
                scrollDelay: sc?.scrollDelay,
                maxScrolls: sc?.maxScrolls,
                overlapRatio: sc?.overlapRatio,
                scrollMode: overrides.scrollMode ?? sc?.scrollMode,
                scrollToTop: sc?.scrollToTop,
                excludeApps: sc?.excludeApps,
                targetApp: sc?.targetApp,
                regionMode: overrides.scrollRegionMode ?? sc?.regionMode,
                region: regionRect ?? sc?.region
            )
        }

        return merged
    }

    /// 문자열을 TargetType으로 변환합니다.
    private static func parseTargetType(_ value: String) -> ScreenCaptureConfig.TargetType? {
        let lowerValue = value.lowercased()
        switch lowerValue {
        case "all":
            return .all
        case "region", "region_user":
            return .region
        case "staticregion", "region_static":
            return .staticRegion
        case "scroll_capture", "scroll":
            return .scrollCapture
        case "window", "window_active", "window_pointer", "window_flash":
            return .single(value)
        default:
            // screen:숫자 패턴 검사
            if lowerValue.hasPrefix("screen:") {
                let numberPart = String(lowerValue.dropFirst(7))
                if Int(numberPart) != nil {
                    return .single(value)
                }
            }
            // 유효하지 않은 target
            return nil
        }
    }

    static func main() {
        initializeConfigFiles()

        let args = CommandLine.arguments

        // -h 플래그 즉시 처리
        if args.contains("-h") || args.contains("--help") {
            printHelp()
            exit(0)
        }

        // -v 플래그 즉시 처리
        if args.contains("-v") || args.contains("--version") {
            print("fCapture \(appVersion)")
            exit(0)
        }

        let (configFile, presetFlag, overrides) = parseArguments(args)

        var baseConfig: ScreenCaptureConfig

        if let flag = presetFlag {
            switch flag {
            case "-s", "--screen":
                baseConfig = loadFCaptureConfig(fileName: "defaultScreen")
            case "-r", "--region":
                baseConfig = loadFCaptureConfig(fileName: "defaultRegion")
            case "-w", "--window":
                baseConfig = loadFCaptureConfig(fileName: "defaultWindow")
            case "-f", "--fixRegion":
                fixRegion()
                exit(0)
            default:
                baseConfig = loadOrCreateDefaultSetting()
            }
        } else if let file = configFile {
            guard let loadedConfig = loadConfig(from: file) else {
                let errorMessage = "설정 파일을 읽을 수 없습니다: \(file)"
                logE(errorMessage)
                exit(1)
            }
            baseConfig = loadedConfig
        } else if !overrides.targets.isEmpty || overrides.capturePath != nil || overrides.fileFormat != nil ||
                  overrides.shadow != nil || overrides.windowFlash != nil || overrides.result != nil ||
                  overrides.region != nil || overrides.backupPath != nil {
            // CLI 옵션만 있는 경우 → defaultConfig 기반
            baseConfig = ScreenCaptureConfig.defaultConfig
        } else {
            baseConfig = loadOrCreateDefaultSetting()
        }

        let config = mergeConfig(base: baseConfig, overrides: overrides)

        // 지연 캡처: 캡처 직전 N초 대기. 모든 캡처 모드에 공통 적용.
        // 우선순위: CLI --relay > 설정 파일(JSON/companion YAML) relay
        if let relay = overrides.relay ?? config.relay, relay > 0 {
            logI("\(relay)초 후 캡처를 실행합니다...")
            Thread.sleep(forTimeInterval: relay)
        }

        performCapture(with: config)
    }
    
    // MARK: - Configuration Loading

    /// 앱 시작 시 항상 호출. ~/.fCapture/ 디렉토리와 4개 기본 설정 파일을 보장.
    static func initializeConfigFiles() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let fCaptureDir = homeDir.appendingPathComponent(".fCapture")
        try? FileManager.default.createDirectory(at: fCaptureDir, withIntermediateDirectories: true)
        createBundleFileIfNeeded(fileName: "defaultSetting", fCaptureDir: fCaptureDir)
        createBundleFileIfNeeded(fileName: "defaultScreen", fCaptureDir: fCaptureDir)
        createBundleFileIfNeeded(fileName: "defaultRegion", fCaptureDir: fCaptureDir)
        createBundleFileIfNeeded(fileName: "defaultWindow", fCaptureDir: fCaptureDir)
        createBundleYAMLIfNeeded(fileName: "default", fCaptureDir: fCaptureDir)
    }

    /// 번들 YAML 파일을 ~/.fCapture/ 에 복사. 이미 존재하면 스킵.
    private static func createBundleYAMLIfNeeded(fileName: String, fCaptureDir: URL) {
        let destFile = fCaptureDir.appendingPathComponent("\(fileName).yml")
        guard !FileManager.default.fileExists(atPath: destFile.path) else { return }
        logI("~/.fCapture/\(fileName).yml 이 없어 기본 템플릿으로 생성합니다")
        guard let templateURL = Bundle.main.url(forResource: fileName, withExtension: "yml") else {
            logE("번들에서 \(fileName).yml 템플릿을 찾을 수 없습니다")
            return
        }
        do {
            try FileManager.default.copyItem(at: templateURL, to: destFile)
            logI("~/.fCapture/\(fileName).yml 생성 완료")
        } catch {
            logE("~/.fCapture/\(fileName).yml 생성 실패: \(error.localizedDescription)")
        }
    }

    /// ~/.fCapture/defaultSetting.json 로드. 없으면 기본값으로 생성.
    static func loadOrCreateDefaultSetting() -> ScreenCaptureConfig {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let fCaptureDir = homeDir.appendingPathComponent(".fCapture")
        let defaultSettingFile = fCaptureDir.appendingPathComponent("defaultSetting.json")

        if FileManager.default.fileExists(atPath: defaultSettingFile.path) {
            if let config = loadConfig(from: defaultSettingFile.path) {
                logI("~/.fCapture/defaultSetting.json 을 사용합니다")
                return config
            }
            logE("~/.fCapture/defaultSetting.json 파싱 오류, 기본값 사용")
            return .defaultConfig
        }

        // 파일 없으면 번들 템플릿으로 생성
        logI("~/.fCapture/defaultSetting.json 이 없어 기본 템플릿으로 생성합니다")
        guard let templateURL = Bundle.main.url(forResource: "defaultSetting", withExtension: "json") else {
            logE("번들에서 defaultSetting.json 템플릿을 찾을 수 없습니다")
            return .defaultConfig
        }
        do {
            try FileManager.default.copyItem(at: templateURL, to: defaultSettingFile)
            logI("~/.fCapture/defaultSetting.json 생성 완료")
        } catch {
            logE("~/.fCapture/defaultSetting.json 생성 실패: \(error.localizedDescription)")
            return .defaultConfig
        }
        return loadConfig(from: defaultSettingFile.path) ?? .defaultConfig
    }

    /// ~/.fCapture/{fileName}.json 로드. 없으면 번들 기본값으로 생성 후 로드.
    static func loadFCaptureConfig(fileName: String) -> ScreenCaptureConfig {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let fCaptureDir = homeDir.appendingPathComponent(".fCapture")
        let configFile = fCaptureDir.appendingPathComponent("\(fileName).json")

        if let config = loadConfig(from: configFile.path) {
            logI("~/.fCapture/\(fileName).json 을 사용합니다")
            return config
        }

        createBundleFileIfNeeded(fileName: fileName, fCaptureDir: fCaptureDir)
        return loadConfig(from: configFile.path) ?? .defaultConfig
    }

    /// 번들 JSON 파일을 ~/.fCapture/ 에 복사. 이미 존재하면 스킵.
    private static func createBundleFileIfNeeded(fileName: String, fCaptureDir: URL) {
        let destFile = fCaptureDir.appendingPathComponent("\(fileName).json")
        guard !FileManager.default.fileExists(atPath: destFile.path) else { return }

        logI("~/.fCapture/\(fileName).json 이 없어 기본 템플릿으로 생성합니다")
        guard let templateURL = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            logE("번들에서 \(fileName).json 템플릿을 찾을 수 없습니다")
            return
        }
        do {
            try FileManager.default.copyItem(at: templateURL, to: destFile)
            logI("~/.fCapture/\(fileName).json 생성 완료")
        } catch {
            logE("~/.fCapture/\(fileName).json 생성 실패: \(error.localizedDescription)")
        }
    }

    static func loadConfig(from path: String) -> ScreenCaptureConfig? {
        let fileManager = FileManager.default
        let expandedPath = NSString(string: path).expandingTildeInPath

        guard fileManager.fileExists(atPath: expandedPath) else {
            print("설정 파일이 존재하지 않습니다: \(expandedPath)")
            return nil
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
            guard var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logE("JSON 파싱 오류: 객체 형식이 아님")
                return nil
            }
            resolveRawConfigReferences(&dict)
            let resolvedData = try JSONSerialization.data(withJSONObject: dict)
            let config = try JSONDecoder().decode(ScreenCaptureConfig.self, from: resolvedData)
            return config
        } catch {
            logE("JSON 파싱 오류: \(error)")
            return nil
        }
    }

    static func printHelp() {
        if let url = Bundle.main.url(forResource: "Usage", withExtension: "txt"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            print(content)
        } else {
            print("Usage: fCapture [options] | fCapture [config.json]")
            print("")
            print("프리셋 플래그:")
            print("  -v, --version             버전 출력")
            print("  -h, --help                도움말 출력")
            print("  -s, --screen              스크린 전체 캡처 (defaultScreen.json 사용)")
            print("  -w, --window              윈도우 캡처 (defaultWindow.json 사용)")
            print("  -f, --fixRegion           마지막 영역 좌표 고정")
            print("")
            print("캡처 대상 옵션 (반복 가능):")
            print("  -t, --target <value>      캡처 대상 (window_pointer/window_active/window_flash/screen:N/all/region_user/region_static)")
            print("                             - window_pointer: 마우스 위치 윈도우 (기본값)")
            print("                             - window_active: 활성 윈도우")
            print("                             - window_flash: 활성 윈도우 + 플래시")
            print("                             - scroll_capture: 활성 윈도우 자동 스크롤 캡처 (스티칭)")
            print("                             - screen:1,2,...: 특정 디스플레이")
            print("                             - all: 모든 디스플레이")
            print("                             - region_user: 사용자가 선택한 영역 (인터랙티브)")
            print("                             - region_static: 고정 좌표 영역 (--region 필수)")
            print("")
            print("파일 관련 옵션:")
            print("  -p, --path <path>         저장 경로 (기본값: ~/Desktop)")
            print("  -F, --format <template>   파일명 템플릿 (%d, %T, %target, %id)")
            print("                             예: screenshot_%d_%T_%target.png")
            print("")
            print("화면 옵션:")
            print("  --shadow                  윈도우 그림자 포함")
            print("  --no-shadow               윈도우 그림자 제외 (기본값)")
            print("  --flash                   캡처 플래시 피드백 활성화")
            print("  --no-flash                캡처 플래시 피드백 비활성화 (기본값)")
            print("")
            print("영역 옵션:")
            print("  --region <x,y,w,h>       정적 영역 좌표 (region_static 타겟 필수)")
            print("                             예: --region 100,100,800,600")
            print("")
            print("출력 옵션:")
            print("  -R, --result <format>     출력 형식 (text/json/onlyPath)")
            print("                             - text: 상세 메시지 (기본값)")
            print("                             - json: JSON 배열")
            print("                             - onlyPath: 파일 경로만")
            print("")
            print("백업 옵션:")
            print("  --backup <path>           다른 화면 백업 경로")
            print("")
            print("지연 옵션:")
            print("  --relay <N>               캡처를 N초 지연 후 실행 (예: --relay 3)")
            print("")
            print("예시:")
            print("  fCapture                                      # 기본 설정 사용")
            print("  fCapture -s                                   # 스크린 전체 캡처")
            print("  fCapture -t screen:1 -p ~/Downloads          # screen:1 을 ~/Downloads에 저장")
            print("  fCapture -t region_static --region 100,100,800,600  # 고정 영역 캡처")
            print("  fCapture data/settings/my_config.json         # 지정한 JSON 설정 파일 사용")
            print("  fCapture --relay 3 -t window_active           # 3초 지연 후 활성 윈도우 캡처")
        }
    }

    static func fixRegion() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let fCaptureDir = homeDir.appendingPathComponent(".fCapture")
        let defaultRegionFile = fCaptureDir.appendingPathComponent("defaultRegion.json")

        let bounds: StateManager.RegionBounds
        if let lastRegion = StateManager.shared.getLastRegion() {
            bounds = lastRegion
            logI("마지막 region 좌표 적용: x=\(bounds.x), y=\(bounds.y), width=\(bounds.width), height=\(bounds.height)")
        } else {
            logW("저장된 region 좌표 없음. screen:1 전체 좌표를 기본값으로 사용합니다")
            let screenCapture = ScreenCapture()
            let displays = screenCapture.getAvailableDisplays()
            if let firstDisplay = displays.first {
                let rect = firstDisplay.bounds
                bounds = StateManager.RegionBounds(
                    x: Double(rect.origin.x),
                    y: Double(rect.origin.y),
                    width: Double(rect.width),
                    height: Double(rect.height)
                )
            } else {
                bounds = StateManager.RegionBounds(x: 0, y: 0, width: 1920, height: 1080)
            }
        }

        createBundleFileIfNeeded(fileName: "defaultRegion", fCaptureDir: fCaptureDir)

        guard let data = try? Data(contentsOf: defaultRegionFile),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logE("defaultRegion.json 읽기 실패")
            return
        }

        json["staticRegion"] = [
            "x": bounds.x,
            "y": bounds.y,
            "width": bounds.width,
            "height": bounds.height
        ]
        json["target"] = "staticRegion"

        do {
            let updatedData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            try updatedData.write(to: defaultRegionFile)
            logI("defaultRegion.json 업데이트 완료: x=\(bounds.x), y=\(bounds.y), w=\(bounds.width), h=\(bounds.height)")
        } catch {
            logE("defaultRegion.json 저장 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - Capture Execution
    static func performCapture(with config: ScreenCaptureConfig) {
        let screenCapture = ScreenCapture()
        
        // 권한 체크
        guard screenCapture.checkScreenRecordingPermission() else {
            logE("스크린 녹화 권한이 필요합니다.")
            logI("시스템 환경설정 > 보안 및 개인 정보 보호 > 화면 및 시스템 오디오 녹화에서 권한을 허용해주세요.")
            exit(1)
        }
        
        // 결과 형식 결정 (JSON > StateManager 기본값 > text)
        let resultFormat = config.result ?? StateManager.shared.getDefaultResultFormat()
        
        // JSON에서 결과 형식이 설정된 경우 StateManager에 저장 (로그 출력은 조건부)
        if let configResult = config.result {
            StateManager.shared.setDefaultResultFormat(configResult, logOutput: resultFormat == .text)
        }
        
        // 저장 경로 결정
        let savePath = determineSavePath(from: config)

        // -p 옵션으로 지정된 경로인 경우 경로 검증 및 생성 시도
        if let capturePath = config.capturePath {
            var pathToCheck: String?
            switch capturePath {
            case .string(let pathString):
                let resolved = resolvePathReference(pathString)
                pathToCheck = NSString(string: resolved).expandingTildeInPath
            case .index(_):
                // 배열 인덱스는 검증 불필요
                break
            }

            if let pathToCheck = pathToCheck {
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: pathToCheck) {
                    // 경로 생성 시도
                    do {
                        try fileManager.createDirectory(atPath: pathToCheck, withIntermediateDirectories: true)
                        if resultFormat == .text {
                            logI("저장 경로 생성: \(pathToCheck)")
                        }
                    } catch {
                        let errorMessage = "저장 경로 생성 실패: \(pathToCheck) - \(error.localizedDescription)"
                        logE(errorMessage)
                        exit(1)
                    }
                }
            }
        }

        // target 타입에 따라 처리
        let targetType = config.target ?? .single("window_pointer")
        let targets = getTargetList(from: targetType, using: screenCapture)

        // staticRegion 검증: staticRegion 타겟인데 staticRegion 설정이 없으면 exit(1)
        if case .staticRegion = targetType {
            guard config.staticRegion != nil else {
                let errorMessage = "staticRegion 타겟을 사용하려면 --region <x,y,w,h> 옵션 또는 설정 파일에 staticRegion 설정이 필요합니다"
                logE(errorMessage)
                exit(1)
            }
        }

        var captureResults: [CaptureResult] = []
        
        for (index, target) in targets.enumerated() {
            do {
                // 캡처 실행
                let image = try captureSingleImage(target: target, using: screenCapture, config: config, resultFormat: resultFormat)
                
                // 파일명 생성 (여러 파일인 경우 인덱스 추가)
                let (fileName, currentID) = generateFileNameWithID(from: config, target: target, index: targets.count > 1 ? index : nil)
                let fileURL = savePath.appendingPathComponent(fileName)
                
                // 이미지 저장
                var actualFileURL: URL = fileURL
                var success = true
                
                do {
                    try screenCapture.saveImage(image, to: fileURL)
                    if resultFormat == .text {
                        logI("스크린샷이 저장되었습니다: \(fileURL.path)")
                    }
                    
                    // 성공적으로 저장된 후 상태 업데이트
                    StateManager.shared.updateState(fileName: fileName, id: currentID, logOutput: resultFormat == .text)
                } catch {
                    // 저장 실패 시 바탕화면에 폴백
                    if resultFormat == .text {
                        logE("저장 실패: \(error.localizedDescription)")
                    }
                    let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                    let fallbackURL = desktopPath.appendingPathComponent(fileName)
                    
                    do {
                        try screenCapture.saveImage(image, to: fallbackURL)
                        actualFileURL = fallbackURL
                        if resultFormat == .text {
                            logI("바탕화면에 저장되었습니다: \(fallbackURL.path)")
                        }
                        
                        // 바탕화면 저장 성공 시에도 상태 업데이트
                        StateManager.shared.updateState(fileName: fileName, id: currentID, logOutput: resultFormat == .text)
                    } catch {
                        success = false
                        if resultFormat == .text {
                            logE("바탕화면 저장도 실패했습니다: \(error.localizedDescription)")
                        }
                    }
                }
                
                if success {
                    captureResults.append(CaptureResult(
                        filePath: actualFileURL.path,
                        fileName: fileName,
                        target: target,
                        id: currentID
                    ))
                    
                    // 백업 스크린 캡처 처리
                    if let backupPath = config.backupOtherScreen,
                       shouldBackupOtherScreen(target: target) {
                        if let backupResult = performBackupCapture(
                            mainTarget: target,
                            backupPath: backupPath,
                            config: config,
                            screenCapture: screenCapture,
                            resultFormat: resultFormat
                        ) {
                            captureResults.append(backupResult)
                        }
                    }
                }
                
            } catch {
                let errorMessage = "캡처 실패 (\(target)): \(error.localizedDescription)"
                logE(errorMessage)
            }
        }
        
        // 결과 출력
        outputResults(captureResults, format: resultFormat)
    }
    
    // MARK: - Result Output
    static func outputResults(_ results: [CaptureResult], format: ScreenCaptureConfig.ResultFormat) {
        switch format {
        case .text:
            // 기본 텍스트 출력 - 더 상세한 정보 제공
            if !results.isEmpty {
                let mainResults = results.filter { !$0.fileName.hasPrefix("backup_") }
                let backupResults = results.filter { $0.fileName.hasPrefix("backup_") }
                
                if results.count == 1 {
                    // 단일 파일인 경우는 메시지 출력하지 않음 (이미 개별적으로 출력됨)
                } else if mainResults.count > 0 && backupResults.count > 0 {
                    logI("메인 \(mainResults.count)개, 백업 \(backupResults.count)개 총 \(results.count)개의 스크린샷이 저장되었습니다")
                } else {
                    logI("총 \(results.count)개의 스크린샷이 저장되었습니다")
                }
            }
            
        case .onlyPath:
            // 파일 경로만 출력 (여러 파일은 개행으로 구분)
            for result in results {
                print(result.filePath)
            }
            
        case .json:
            // JSON 형식으로 출력
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(results)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } catch {
                logE("JSON 출력 실패: \(error.localizedDescription)")
                // JSON 실패 시 폴백으로 경로만 출력
                for result in results {
                    print(result.filePath)
                }
            }
        }
    }
    
    // MARK: - Target Processing
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
        case .scrollCapture:
            return ["scroll_capture"]
        }
    }

    // MARK: - Capture Logic
    static func captureSingleImage(target: String, using screenCapture: ScreenCapture, config: ScreenCaptureConfig, resultFormat: ScreenCaptureConfig.ResultFormat) throws -> NSImage {
        if target == "scroll_capture" {
            // 활성 윈도우 자동 스크롤 캡처 + 수직 스티칭
            guard let windowID = screenCapture.getFrontmostWindowID() else {
                throw ScreenCapture.ScreenCaptureError.captureFailure("스크롤 캡처: 활성 윈도우를 찾을 수 없습니다")
            }
            if resultFormat == .text {
                logI("스크롤 캡처 모드 시작: 활성 윈도우(\(windowID))를 대상으로 자동 스크롤")
            }
            let sc = config.scrollConfig
            let scrollModeStr = sc?.scrollMode ?? "page"
            let scrollMode: ScrollCaptureEngine.Config.ScrollMode = scrollModeStr == "scroll" ? .scroll : .page
            // regionMode 파싱
            let regionMode: ScrollCaptureEngine.Config.RegionMode
            if let modeStr = sc?.regionMode {
                regionMode = ScrollCaptureEngine.Config.RegionMode(rawValue: modeStr) ?? .auto
            } else {
                regionMode = .auto
            }

            // region rect 파싱
            var regionRect: CGRect? = nil
            if let r = sc?.region {
                regionRect = CGRect(x: r.x, y: r.y, width: r.width, height: r.height)
            }

            let engineConfig = ScrollCaptureEngine.Config(
                scrollAmount: sc?.scrollAmount ?? 8,
                scrollDelay: sc?.scrollDelay ?? 0.5,
                maxScrolls: sc?.maxScrolls ?? 30,
                overlapRatio: sc?.overlapRatio ?? 0.25,
                scrollMode: scrollMode,
                scrollToTop: sc?.scrollToTop ?? true,
                excludeApps: sc?.excludeApps ?? [],
                targetApp: sc?.targetApp,
                regionMode: regionMode,
                region: regionRect
            )
            let engine = ScrollCaptureEngine()
            return try engine.captureWithScroll(
                fallbackWindowID: windowID,
                config: engineConfig,
                shadow: config.shadow ?? false
            )
        } else if target == "region" {
            // 동적 영역 선택 캡처 (사용자가 영역 선택)
            if resultFormat == .text {
                logI("인터랙티브 캡처 모드 시작: Space키로 윈도우/영역 전환, ESC로 취소")
            }
            return try captureSelectedRegion(logOutput: resultFormat == .text)
        } else if target == "window" || target == "window_pointer" {
            // 마우스 포인터 위치의 윈도우 자동 캡처
            if resultFormat == .text {
                logI("윈도우 포인터 캡처 모드: 마우스 위치의 윈도우를 캡처합니다")
            }
            return try captureWindowPoint(logOutput: resultFormat == .text, windowFlash: config.windowFlash ?? true, shadow: config.shadow ?? false)
        } else if target == "staticRegion" {
            // 정적 영역 캡처 (설정된 좌표 또는 --region 옵션)
            guard let staticRegionConfig = config.staticRegion else {
                let errorMessage = "staticRegion 타겟을 사용하려면 --region <x,y,w,h> 옵션 또는 설정 파일에 staticRegion 설정이 필요합니다"
                logE(errorMessage)
                throw ScreenCapture.ScreenCaptureError.captureFailure(errorMessage)
            }
            if resultFormat == .text {
                logI("정적영역 캡처: x=\(staticRegionConfig.x), y=\(staticRegionConfig.y), width=\(staticRegionConfig.width), height=\(staticRegionConfig.height)")
            }
            return try screenCapture.captureRegion(staticRegionConfig.cgRect)
        } else if target.hasPrefix("screen:") {
            // 특정 디스플레이 캡처
            let screenNumberString = String(target.dropFirst(7)) // "screen:" 이후 숫자 추출
            guard let screenNumber = Int(screenNumberString) else {
                throw ScreenCapture.ScreenCaptureError.captureFailure("잘못된 스크린 번호: \(target)")
            }
            
            return try screenCapture.captureDisplay(displayNumber: screenNumber)
        } else if target == "window_active" {
            // 활성 윈도우 캡처 (CGWindowList front-to-back 순서, layer==0인 첫 번째 윈도우)
            guard let windowID = screenCapture.getFrontmostWindowID() else {
                throw ScreenCapture.ScreenCaptureError.captureFailure("활성 윈도우를 찾을 수 없습니다")
            }
            let options = ScreenCapture.CaptureOptions(includeWindowShadow: config.shadow ?? false)
            let image = try screenCapture.captureWindow(windowID: windowID, options: options)
            if config.windowFlash ?? true { flashWindowBounds(windowID: windowID) }
            return image
        } else if target == "window_flash" {
            // 활성 윈도우 캡처 + 캡처 영역 flash 피드백
            guard let windowID = screenCapture.getFrontmostWindowID() else {
                throw ScreenCapture.ScreenCaptureError.captureFailure("활성 윈도우를 찾을 수 없습니다")
            }
            let options = ScreenCapture.CaptureOptions(includeWindowShadow: config.shadow ?? false)
            let image = try screenCapture.captureWindow(windowID: windowID, options: options)
            flashWindowBounds(windowID: windowID)
            return image
        } else {
            throw ScreenCapture.ScreenCaptureError.captureFailure("알 수 없는 target: '\(target)'. 유효한 target: window_active, window_flash, window_pointer, screen:N, all, region_user, region_static")
        }
    }
    
    // MARK: - Region Capture
    static func captureSelectedRegion(logOutput: Bool = true) throws -> NSImage {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fCapture_temp_\(UUID().uuidString).png")

        // 마우스 드래그 좌표 추적용 버퍼 (CGEvent tap)
        // [0] = mouseDown, [1] = mouseUp, (-1,-1) = 미설정
        let mouseLocations = UnsafeMutablePointer<CGPoint>.allocate(capacity: 2)
        mouseLocations.initialize(repeating: CGPoint(x: -1, y: -1), count: 2)
        defer { mouseLocations.deallocate() }

        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)
        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let locations = refcon.assumingMemoryBound(to: CGPoint.self)
                if type == .leftMouseDown {
                    locations[0] = event.location
                } else if type == .leftMouseUp {
                    locations[1] = event.location
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(mouseLocations)
        )

        var runLoopSource: CFRunLoopSource?
        if let eventTap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }

        defer {
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: false)
                if let source = runLoopSource {
                    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
                }
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", tempFile.path]

        do {
            try process.run()

            // RunLoop을 돌면서 CGEvent tap 콜백 처리
            while process.isRunning {
                CFRunLoopRunInMode(.defaultMode, 0.05, false)
            }

            if process.terminationStatus == 0 {
                let imageData = try Data(contentsOf: tempFile)
                guard let nsImage = NSImage(data: imageData) else {
                    throw ScreenCapture.ScreenCaptureError.captureFailure("이미지 데이터를 읽을 수 없습니다")
                }
                try? FileManager.default.removeItem(at: tempFile)

                // 드래그 좌표가 캡처된 경우 lastRegion 저장
                let down = mouseLocations[0]
                let up = mouseLocations[1]
                if down.x >= 0 && up.x >= 0 {
                    let x = min(down.x, up.x)
                    let y = min(down.y, up.y)
                    let w = abs(up.x - down.x)
                    let h = abs(up.y - down.y)
                    if w > 0 && h > 0 {
                        let bounds = StateManager.RegionBounds(x: x, y: y, width: w, height: h)
                        StateManager.shared.saveLastRegion(bounds, logOutput: logOutput)
                    }
                }

                if logOutput {
                    logI("인터랙티브 캡처 완료")
                }
                return nsImage
            } else {
                throw ScreenCapture.ScreenCaptureError.captureFailure("영역 선택이 취소되었거나 실패했습니다")
            }
        } catch {
            if logOutput {
                logE("screencapture 실행 오류: \(error.localizedDescription)")
            }
            throw ScreenCapture.ScreenCaptureError.captureFailure("screencapture 명령 실행 실패: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Window Point Capture
    static func captureWindowPoint(logOutput: Bool = true, windowFlash: Bool = true, shadow: Bool = false) throws -> NSImage {
        let screenCapture = ScreenCapture()
        let mouseLocation = NSEvent.mouseLocation

        // macOS 좌표계 변환 (NSEvent은 좌하단 원점, CGWindowList는 좌상단 원점)
        guard let mainScreen = NSScreen.screens.first else {
            throw ScreenCapture.ScreenCaptureError.captureFailure("스크린 정보를 가져올 수 없습니다")
        }
        let cgMouseY = mainScreen.frame.height - mouseLocation.y
        let cgMousePoint = CGPoint(x: mouseLocation.x, y: cgMouseY)

        // 마우스 포인터 위치에 있는 윈도우 찾기
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            throw ScreenCapture.ScreenCaptureError.captureFailure("윈도우 목록을 가져올 수 없습니다")
        }

        var targetWindowID: CGWindowID? = nil
        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  !ownerName.isEmpty,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let wx = boundsDict["X"], let wy = boundsDict["Y"],
                  let ww = boundsDict["Width"], let wh = boundsDict["Height"] else {
                continue
            }

            // 시스템 UI 요소 제외
            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 { continue }

            let windowRect = CGRect(x: wx, y: wy, width: ww, height: wh)
            if windowRect.contains(cgMousePoint) {
                targetWindowID = windowID
                if logOutput {
                    let windowName = windowInfo[kCGWindowName as String] as? String ?? ""
                    logI("포인터 위치 윈도우 감지: \(ownerName) - \(windowName)")
                }
                break
            }
        }

        guard let windowID = targetWindowID else {
            throw ScreenCapture.ScreenCaptureError.captureFailure("마우스 포인터 위치에 윈도우가 없습니다")
        }

        let options = ScreenCapture.CaptureOptions(includeWindowShadow: shadow)
        let image = try screenCapture.captureWindow(windowID: windowID, options: options)
        if windowFlash { flashWindowBounds(windowID: windowID) }
        if logOutput {
            logI("윈도우 포인트 캡처 완료")
        }
        return image
    }

    // MARK: - Window Flash Feedback
    /// 캡처 완료 피드백: 캡처된 윈도우 위치에 파란 테두리 오버레이를 0.5초 표시
    static func flashWindowBounds(windowID: CGWindowID) {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionIncludingWindow], windowID
        ) as? [[String: Any]],
        let windowInfo = windowList.first,
        let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
        let cgBounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
        let mainScreen = NSScreen.main else { return }

        // CGWindowList(좌상단 기준) → NSWindow(주화면 좌하단 기준) 좌표 변환
        let screenHeight = mainScreen.frame.height
        let nsRect = NSRect(
            x: cgBounds.origin.x,
            y: screenHeight - cgBounds.origin.y - cgBounds.height,
            width: cgBounds.width,
            height: cgBounds.height
        )

        NSApplication.shared.setActivationPolicy(.accessory)

        let flashWindow = NSWindow(
            contentRect: nsRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        flashWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        flashWindow.isOpaque = false
        flashWindow.hasShadow = false
        flashWindow.ignoresMouseEvents = true
        flashWindow.backgroundColor = .clear

        let contentView = NSView(frame: NSRect(origin: .zero, size: nsRect.size))
        contentView.wantsLayer = true
        contentView.layer?.borderColor = NSColor.systemBlue.cgColor
        contentView.layer?.borderWidth = 4
        contentView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.15).cgColor
        flashWindow.contentView = contentView

        flashWindow.makeKeyAndOrderFront(nil)

        // RunLoop 0.5초 실행 후 닫기
        let displayEnd = Date().addingTimeInterval(0.5)
        while Date() < displayEnd {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        flashWindow.close()
    }

    // MARK: - Backup Screen Functions
    static func shouldBackupOtherScreen(target: String) -> Bool {
        return target == "screen:1" || target == "screen:2"
    }
    
    static func getBackupTarget(for mainTarget: String) -> String? {
        switch mainTarget {
        case "screen:1": return "screen:2"
        case "screen:2": return "screen:1"
        default: return nil
        }
    }
    
    static func performBackupCapture(
        mainTarget: String,
        backupPath: String,
        config: ScreenCaptureConfig,
        screenCapture: ScreenCapture,
        resultFormat: ScreenCaptureConfig.ResultFormat
    ) -> CaptureResult? {
        guard let backupTarget = getBackupTarget(for: mainTarget) else {
            return nil
        }
        
        do {
            // 백업 스크린 캡처
            let backupImage = try captureSingleImage(
                target: backupTarget,
                using: screenCapture,
                config: config,
                resultFormat: resultFormat
            )
            
            // 백업 파일명 생성 (backup_ 접두사 추가)
            let (originalFileName, backupID) = generateFileNameWithID(
                from: config,
                target: backupTarget,
                index: nil
            )
            let backupFileName = "backup_\(originalFileName)"
            
            // 백업 경로 처리
            let expandedBackupPath = NSString(string: backupPath).expandingTildeInPath
            let backupURL = URL(fileURLWithPath: expandedBackupPath)
            let backupFileURL = backupURL.appendingPathComponent(backupFileName)
            
            // 백업 이미지 저장
            do {
                try screenCapture.saveImage(backupImage, to: backupFileURL)
                if resultFormat == .text {
                    logI("백업 스크린샷이 저장되었습니다: \(backupFileURL.path)")
                }
                
                // 백업 상태 업데이트 (로그 출력 없음)
                StateManager.shared.updateState(fileName: backupFileName, id: backupID, logOutput: false)
                
                return CaptureResult(
                    filePath: backupFileURL.path,
                    fileName: backupFileName,
                    target: backupTarget,
                    id: backupID
                )
            } catch {
                // 백업 저장 실패 시 폴백 (바탕화면)
                let backupErrorMessage = "백업 저장 실패: \(error.localizedDescription)"
                logW(backupErrorMessage)
                let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                let fallbackURL = desktopPath.appendingPathComponent(backupFileName)
                
                do {
                    try screenCapture.saveImage(backupImage, to: fallbackURL)
                    if resultFormat == .text {
                        logI("백업이 바탕화면에 저장되었습니다: \(fallbackURL.path)")
                    }
                    
                    StateManager.shared.updateState(fileName: backupFileName, id: backupID, logOutput: false)
                    
                    return CaptureResult(
                        filePath: fallbackURL.path,
                        fileName: backupFileName,
                        target: backupTarget,
                        id: backupID
                    )
                } catch {
                    let finalErrorMessage = "백업 바탕화면 저장도 실패했습니다: \(error.localizedDescription)"
                    logE(finalErrorMessage)
                    return nil
                }
            }
        } catch {
            if resultFormat == .text {
                logE("백업 캡처 실패 (\(backupTarget)): \(error.localizedDescription)")
            }
            return nil
        }
    }
    
    // MARK: - Helper Functions
    static func getFrontmostWindow(from windows: [(windowID: CGWindowID, name: String, ownerName: String)]) -> (windowID: CGWindowID, name: String, ownerName: String)? {
        // NSWorkspace를 사용하여 현재 활성 윈도우 찾기
        let workspace = NSWorkspace.shared
        guard let frontmostApp = workspace.frontmostApplication else {
            return windows.first
        }

        // 활성 윈도우 찾기
        let frontmostAppName = frontmostApp.localizedName ?? ""
        return windows.first { $0.ownerName == frontmostAppName }
    }
    
    // MARK: - Default YAML Support

    /// YAML 배열 파서: `key:\n  - value` 형식의 배열을 추출
    static func parseYAMLArrays(_ content: String) -> [String: [String]] {
        var result: [String: [String]] = [:]
        var currentKey: String? = nil
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            if trimmed.hasPrefix("- ") || trimmed == "-" {
                guard let key = currentKey else { continue }
                var value = trimmed.hasPrefix("- ") ? String(trimmed.dropFirst(2)) : ""
                value = value.trimmingCharacters(in: .whitespaces)
                // 인라인 주석 제거
                if let commentRange = value.range(of: " #") ?? value.range(of: "\t#") {
                    value = String(value[..<commentRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
                // 따옴표 제거
                if value.count >= 2,
                   (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                   (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }
                result[key, default: []].append(value)
            } else if let colonRange = trimmed.range(of: ":") {
                let key = String(trimmed[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let rawValue = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                currentKey = rawValue.isEmpty ? key : nil
            } else {
                currentKey = nil
            }
        }
        return result
    }

    /// 단순 flat key-value YAML 파서 (중첩 구조 미지원, 인라인 주석 처리)
    static func parseSimpleYAML(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            guard let colonRange = trimmed.range(of: ":") else { continue }
            let key = String(trimmed[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            var rawValue = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            // 따옴표 시작 시 첫 번째 닫는 따옴표까지만 추출 (인라인 주석 내 따옴표 오탐 방지)
            if rawValue.hasPrefix("\"") {
                let inner = rawValue.dropFirst()
                if let closeIdx = inner.firstIndex(of: "\"") {
                    result[key] = String(inner[..<closeIdx])
                } else {
                    result[key] = String(inner)
                }
            } else if rawValue.hasPrefix("'") {
                let inner = rawValue.dropFirst()
                if let closeIdx = inner.firstIndex(of: "'") {
                    result[key] = String(inner[..<closeIdx])
                } else {
                    result[key] = String(inner)
                }
            } else {
                // 인라인 주석 제거 (공백 또는 탭 + # 이후)
                if let commentRange = rawValue.range(of: " #") ?? rawValue.range(of: "\t#") {
                    rawValue = String(rawValue[..<commentRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
                result[key] = rawValue
            }
        }
        return result
    }

    /// 문자열 내 `{경로}` 패턴을 파일 내용으로 치환 (임베디드 참조, ex: "screen:{ref}")
    static func resolveEmbeddedReferences(_ value: String) -> String {
        guard value.contains("{") else { return value }
        var result = value
        // {경로} 패턴을 뒤에서부터 치환 (인덱스 보정)
        guard let regex = try? NSRegularExpression(pattern: "\\{([^}]+)\\}") else { return value }
        let nsResult = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsResult.length))
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: result),
                  let groupRange = Range(match.range(at: 1), in: result) else { continue }
            let refPath = String(result[groupRange])
            let expandedPath = NSString(string: refPath).expandingTildeInPath
            if let content = try? String(contentsOfFile: expandedPath, encoding: .utf8) {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    result.replaceSubrange(matchRange, with: trimmed)
                }
            }
        }
        return result
    }

    /// 파일 미존재 시 동명 companion YAML 경로 탐색
    /// ex: t4.basePath.txt → t4.basePath.default.yaml 또는 t4.default.yaml
    static func findCompanionYAML(forPath expandedPath: String) -> String? {
        let lower = expandedPath.lowercased()
        guard !lower.hasSuffix(".yaml"), !lower.hasSuffix(".yml") else { return nil }
        guard !FileManager.default.fileExists(atPath: expandedPath) else { return nil }
        let dir = (expandedPath as NSString).deletingLastPathComponent
        let fileName = (expandedPath as NSString).lastPathComponent
        let baseName = (fileName as NSString).deletingPathExtension       // "t4.basePath"
        let firstPart = baseName.components(separatedBy: ".").first ?? baseName  // "t4"
        for ext in ["default.yaml", "yaml", "yml"] {
            // 1순위: 전체 baseName (t4.basePath.default.yaml)
            let c1 = (dir as NSString).appendingPathComponent("\(baseName).\(ext)")
            if FileManager.default.fileExists(atPath: c1) {
                logI("\(fileName) 미존재 → companion \(baseName).\(ext) 사용")
                return c1
            }
            // 2순위: 첫 컴포넌트만 (t4.default.yaml)
            if firstPart != baseName {
                let c2 = (dir as NSString).appendingPathComponent("\(firstPart).\(ext)")
                if FileManager.default.fileExists(atPath: c2) {
                    logI("\(fileName) 미존재 → companion \(firstPart).\(ext) 사용")
                    return c2
                }
            }
        }
        return nil
    }

    /// `{경로}` 패턴에서 YAML 특정 키 값 또는 평문 파일 전체 내용 반환 (companion YAML 지원)
    static func resolveFieldFromReference(_ refString: String, field: String) -> String? {
        guard refString.hasPrefix("{"), refString.hasSuffix("}") else { return nil }
        let refPath = String(refString.dropFirst().dropLast())
        var expandedPath = NSString(string: refPath).expandingTildeInPath
        if let companion = findCompanionYAML(forPath: expandedPath) {
            expandedPath = companion
        }
        guard FileManager.default.fileExists(atPath: expandedPath),
              let content = try? String(contentsOfFile: expandedPath, encoding: .utf8) else {
            return nil
        }
        let lower = expandedPath.lowercased()
        if lower.hasSuffix(".yaml") || lower.hasSuffix(".yml") {
            let yaml = parseSimpleYAML(content)
            return yaml[field]
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// raw JSON dict 내의 `{ref}` 패턴을 실제 값으로 치환 (JSONDecoder 실행 전 전처리)
    static func resolveRawConfigReferences(_ dict: inout [String: Any]) {
        // 문자열 필드 해석
        for field in ["fileFormat", "result", "backupOtherScreen"] {
            if let value = dict[field] as? String, value.hasPrefix("{") {
                if let resolved = resolveFieldFromReference(value, field: field) {
                    dict[field] = resolved.isEmpty ? NSNull() : resolved
                } else {
                    dict.removeValue(forKey: field)
                }
            }
        }
        // Bool 필드 해석
        for field in ["shadow", "window_flash"] {
            if let value = dict[field] as? String, value.hasPrefix("{") {
                if let resolved = resolveFieldFromReference(value, field: field) {
                    dict[field] = (resolved.lowercased() == "true")
                } else {
                    dict.removeValue(forKey: field)
                }
            }
        }
        // target 특수: "screen:{ref}" → YAML target.number 또는 txt 내용으로 screen:N 조합
        if let value = dict["target"] as? String,
           value.lowercased().hasPrefix("screen:{"), value.hasSuffix("}") {
            let inner = String(value.dropFirst("screen:".count))  // "{ref}"
            let refPath = String(inner.dropFirst().dropLast())
            let expandedRef = NSString(string: refPath).expandingTildeInPath
            let actualPath = findCompanionYAML(forPath: expandedRef) ?? expandedRef
            let lower = actualPath.lowercased()
            if (lower.hasSuffix(".yaml") || lower.hasSuffix(".yml")),
               let content = try? String(contentsOfFile: actualPath, encoding: .utf8) {
                let yaml = parseSimpleYAML(content)
                var targetName = yaml["target"] ?? ""
                if targetName.isEmpty { targetName = yaml["name"] ?? "screen" }
                if targetName == "screen" {
                    let num = Int(yaml["number"] ?? "1") ?? 1
                    dict["target"] = num == -1 ? "all" : "screen:\(num)"
                }
            } else if FileManager.default.fileExists(atPath: actualPath),
                      let content = try? String(contentsOfFile: actualPath, encoding: .utf8) {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { dict["target"] = "screen:\(trimmed)" }
            } else {
                dict.removeValue(forKey: "target")
            }
        }
        // target: YAML에서 target + number 조합으로 해석 (screen → screen:N, -1 → all)
        if let value = dict["target"] as? String, value.hasPrefix("{") {
            let refPath = String(value.dropFirst().dropLast())
            let expandedRef = NSString(string: refPath).expandingTildeInPath
            let lower = expandedRef.lowercased()
            if (lower.hasSuffix(".yaml") || lower.hasSuffix(".yml")),
               let content = try? String(contentsOfFile: expandedRef, encoding: .utf8) {
                let yaml = parseSimpleYAML(content)
                // target 해석: 단일값 또는 중첩(name + number) 형식 모두 지원
                // 단일: target: screen / 중첩: target:\n  name: screen\n  number: 1
                var targetName = yaml["target"] ?? ""
                if targetName.isEmpty {
                    targetName = yaml["name"] ?? ""
                }
                if targetName == "screen" {
                    let num = Int(yaml["number"] ?? "1") ?? 1
                    dict["target"] = num == -1 ? "all" : "screen:\(num)"
                } else if !targetName.isEmpty {
                    dict["target"] = targetName
                } else {
                    dict.removeValue(forKey: "target")
                }
            } else if let resolved = resolveFieldFromReference(value, field: "target") {
                dict["target"] = resolved
            } else {
                dict.removeValue(forKey: "target")
            }
        }
        // capturePath: companion YAML 지원 → Int(인덱스) 또는 String(경로), 평문 파일 → resolvePathReference
        if let value = dict["capturePath"] as? String, value.hasPrefix("{") {
            let refPath = String(value.dropFirst().dropLast())
            let expandedRef = NSString(string: refPath).expandingTildeInPath
            let actualPath = findCompanionYAML(forPath: expandedRef) ?? expandedRef
            let lower = actualPath.lowercased()
            if lower.hasSuffix(".yaml") || lower.hasSuffix(".yml") {
                if let content = try? String(contentsOfFile: actualPath, encoding: .utf8) {
                    let yaml = parseSimpleYAML(content)
                    if let rawCP = yaml["capturePath"], !rawCP.isEmpty {
                        if let intVal = Int(rawCP) {
                            dict["capturePath"] = intVal
                        } else {
                            dict["capturePath"] = rawCP
                        }
                    } else {
                        dict.removeValue(forKey: "capturePath")
                    }
                }
            } else {
                dict["capturePath"] = resolvePathReference(value)
            }
        }
        // relay: companion YAML 지원 → Double(지연 초). 평문 파일이면 숫자 파싱.
        if let value = dict["relay"] as? String, value.hasPrefix("{") {
            let refPath = String(value.dropFirst().dropLast())
            let expandedRef = NSString(string: refPath).expandingTildeInPath
            let actualPath = findCompanionYAML(forPath: expandedRef) ?? expandedRef
            let lower = actualPath.lowercased()
            var resolved = false
            if lower.hasSuffix(".yaml") || lower.hasSuffix(".yml"),
               let content = try? String(contentsOfFile: actualPath, encoding: .utf8) {
                let yaml = parseSimpleYAML(content)
                if let rawRelay = yaml["relay"], let relayVal = Double(rawRelay) {
                    dict["relay"] = relayVal
                    resolved = true
                }
            } else if let resolvedStr = resolveFieldFromReference(value, field: "relay"),
                      let relayVal = Double(resolvedStr) {
                dict["relay"] = relayVal
                resolved = true
            }
            if !resolved {
                dict.removeValue(forKey: "relay")
            }
        }
        // 임베디드 {ref} 해석: 값 일부에 {경로} 포함된 평문 파일 참조 (target은 위에서 별도 처리)
        for field in ["fileFormat", "backupOtherScreen"] {
            if let value = dict[field] as? String, !value.hasPrefix("{"), value.contains("{") {
                dict[field] = resolveEmbeddedReferences(value)
            }
        }
        // capturePathArray: YAML 배열에서 읽기 (companion YAML 지원). 해석 실패 시 키 제거
        if let value = dict["capturePathArray"] as? String, value.hasPrefix("{") {
            let refPath = String(value.dropFirst().dropLast())
            let expandedRef = NSString(string: refPath).expandingTildeInPath
            let actualPath = findCompanionYAML(forPath: expandedRef) ?? expandedRef
            let lower = actualPath.lowercased()
            var resolved = false
            if lower.hasSuffix(".yaml") || lower.hasSuffix(".yml"),
               let content = try? String(contentsOfFile: actualPath, encoding: .utf8) {
                let arrays = parseYAMLArrays(content)
                if let pathArray = arrays["capturePathArray"], !pathArray.isEmpty {
                    dict["capturePathArray"] = pathArray
                    resolved = true
                }
            }
            if !resolved {
                dict.removeValue(forKey: "capturePathArray")
            }
        }
    }

    /// `{~/.fCapture/basePath.txt}` 형식의 경로를 해석하여 파일 내용으로 치환.
    /// 파일이 없으면 기본값(~/Desktop)으로 생성.
    static func resolvePathReference(_ pathString: String) -> String {
        // {파일경로} 패턴 검출
        guard pathString.hasPrefix("{") && pathString.hasSuffix("}") else {
            return pathString
        }
        let refPath = String(pathString.dropFirst().dropLast())
        let expandedRefPath = NSString(string: refPath).expandingTildeInPath
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: expandedRefPath) {
            if let content = try? String(contentsOfFile: expandedRefPath, encoding: .utf8) {
                let resolved = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !resolved.isEmpty {
                    logI("\(refPath) → \(resolved)")
                    return resolved
                }
            }
        }

        // 파일 미존재 또는 빈 파일 → 기본값으로 생성
        let defaultPath = "~/Desktop"
        let dir = (expandedRefPath as NSString).deletingLastPathComponent
        try? fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? defaultPath.write(toFile: expandedRefPath, atomically: true, encoding: .utf8)
        logI("\(refPath) 미존재 → 기본값(\(defaultPath))으로 생성")
        return defaultPath
    }

    static func determineSavePath(from config: ScreenCaptureConfig) -> URL {
        if let capturePath = config.capturePath {
            switch capturePath {
            case .string(let pathString):
                // {파일참조} 또는 문자열 경로 사용
                let resolved = resolvePathReference(pathString)
                let expandedPath = NSString(string: resolved).expandingTildeInPath
                return URL(fileURLWithPath: expandedPath)
            case .index(let index):
                // 배열 인덱스 사용
                if let pathArray = config.capturePathArray, 
                   index >= 0 && index < pathArray.count {
                    let selectedPath = pathArray[index]
                    let expandedPath = NSString(string: selectedPath).expandingTildeInPath
                    return URL(fileURLWithPath: expandedPath)
                } else {
                    logW("인덱스 \(index)가 유효하지 않거나 capturePathArray가 없습니다. 기본 경로를 사용합니다.")
                    return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                }
            }
        } else {
            // 시스템 기본 스크린샷 저장 경로 사용
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        }
    }
    
    static func generateFileNameWithID(from config: ScreenCaptureConfig, target: String, index: Int?) -> (String, Int) {
        let format = config.fileFormat ?? "%d_%T"
        let now = Date()
        
        let dateFormatter = DateFormatter()
        let timeFormatter = DateFormatter()
        
        // %d: 날짜 (yyyyMMdd)
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: now)
        
        // %T: 시간 (HHmmss)
        timeFormatter.dateFormat = "HHmmss"
        let timeString = timeFormatter.string(from: now)
        
        // %target: 캡처 대상 ("window", "screen1", "screen2", "screen3")
        let targetString = target.hasPrefix("screen:") ?
            target.replacingOccurrences(of: ":", with: "") : target

        // %id: ID 카운터 (001, 002, 003...)
        let currentID = StateManager.shared.getNextID()
        let idString = String(format: "%03d", currentID)

        var fileName = format
            .replacingOccurrences(of: "%d", with: dateString)
            .replacingOccurrences(of: "%T", with: timeString)
            .replacingOccurrences(of: "%target", with: targetString)
            .replacingOccurrences(of: "%id", with: idString)

        // 여러 파일인 경우 인덱스 추가 (확장자 앞에)
        if let index = index {
            let parts = fileName.components(separatedBy: ".")
            if parts.count > 1 {
                let nameWithoutExt = parts.dropLast().joined(separator: ".")
                let ext = parts.last!
                fileName = "\(nameWithoutExt)_\(index+1).\(ext)"
            } else {
                fileName += "_\(index+1)"
            }
        }

        // 파일 확장자가 없으면 .png 추가
        if !fileName.contains(".") {
            fileName += ".png"
        }

        return (fileName, currentID)
    }

    static func generateFileName(from config: ScreenCaptureConfig, target: String, index: Int?) -> String {
        let format = config.fileFormat ?? "%d_%T"
        let now = Date()

        let dateFormatter = DateFormatter()
        let timeFormatter = DateFormatter()

        // %d: 날짜 (yyyyMMdd)
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: now)

        // %T: 시간 (HHmmss)
        timeFormatter.dateFormat = "HHmmss"
        let timeString = timeFormatter.string(from: now)

        // %target: 캡처 대상 ("window", "screen1", "screen2", "screen3")
        let targetString = target.hasPrefix("screen:") ?
            target.replacingOccurrences(of: ":", with: "") : target
        
        // %id: ID 카운터 (001, 002, 003...)
        let currentID = StateManager.shared.getNextID()
        let idString = String(format: "%03d", currentID)
        
        var fileName = format
            .replacingOccurrences(of: "%d", with: dateString)
            .replacingOccurrences(of: "%T", with: timeString)
            .replacingOccurrences(of: "%target", with: targetString)
            .replacingOccurrences(of: "%id", with: idString)
        
        // 여러 파일인 경우 인덱스 추가 (확장자 앞에)
        if let index = index {
            let parts = fileName.components(separatedBy: ".")
            if parts.count > 1 {
                let nameWithoutExt = parts.dropLast().joined(separator: ".")
                let ext = parts.last!
                fileName = "\(nameWithoutExt)_\(index+1).\(ext)"
            } else {
                fileName += "_\(index+1)"
            }
        }
        
        // 파일 확장자가 없으면 .png 추가
        if !fileName.contains(".") {
            fileName += ".png"
        }
        
        return fileName
    }
}
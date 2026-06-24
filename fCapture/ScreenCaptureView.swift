import SwiftUI
import AppKit

/// 스크린샷 캡처를 위한 SwiftUI 뷰
public struct ScreenCaptureView: View {
    
    @State private var capturedImage: NSImage?
    @State private var isCapturing = false
    @State private var errorMessage: String?
    @State private var showSavePanel = false
    @State private var captureOptions = ScreenCapture.CaptureOptions()
    @State private var availableWindows: [(windowID: CGWindowID, name: String, ownerName: String)] = []
    @State private var selectedWindowIndex = 0
    
    private let screenCapture = ScreenCapture()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("📸 Screen Capture Tool")
                .font(.title)
                .fontWeight(.bold)
            
            // Options Section
            GroupBox("캡처 옵션") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("이미지 포맷:")
                        Picker("Format", selection: $captureOptions.imageFormat) {
                            Text("PNG").tag(ScreenCapture.ImageFormat.png)
                            Text("JPEG").tag(ScreenCapture.ImageFormat.jpeg)
                            Text("TIFF").tag(ScreenCapture.ImageFormat.tiff)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    if captureOptions.imageFormat == .jpeg {
                        HStack {
                            Text("품질:")
                            Slider(value: Binding(
                                get: { captureOptions.quality },
                                set: { newValue in
                                    captureOptions = ScreenCapture.CaptureOptions(
                                        includeWindowShadow: captureOptions.includeWindowShadow,
                                        captureMouseCursor: captureOptions.captureMouseCursor,
                                        imageFormat: captureOptions.imageFormat,
                                        quality: newValue
                                    )
                                }
                            ), in: 0.1...1.0, step: 0.1)
                            Text("\(Int(captureOptions.quality * 100))%")
                                .frame(width: 40)
                        }
                    }
                    
                    Toggle("그림자 포함", isOn: Binding(
                        get: { captureOptions.includeWindowShadow },
                        set: { newValue in
                            captureOptions = ScreenCapture.CaptureOptions(
                                includeWindowShadow: newValue,
                                captureMouseCursor: captureOptions.captureMouseCursor,
                                imageFormat: captureOptions.imageFormat,
                                quality: captureOptions.quality
                            )
                        }
                    ))
                    
                    Toggle("마우스 커서 포함", isOn: Binding(
                        get: { captureOptions.captureMouseCursor },
                        set: { newValue in
                            captureOptions = ScreenCapture.CaptureOptions(
                                includeWindowShadow: captureOptions.includeWindowShadow,
                                captureMouseCursor: newValue,
                                imageFormat: captureOptions.imageFormat,
                                quality: captureOptions.quality
                            )
                        }
                    ))
                }
                .padding()
            }
            
            // Capture Buttons
            HStack(spacing: 15) {
                Button(action: captureFullScreen) {
                    HStack {
                        Image(systemName: "display")
                        Text("전체 화면")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCapturing)
                
                Button(action: captureSelectedWindow) {
                    HStack {
                        Image(systemName: "macwindow")
                        Text("활성 창")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isCapturing)
                
                Button(action: refreshWindows) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("창 목록 새로고침")
                    }
                }
                .buttonStyle(.bordered)
            }
            
            // Window Selection
            if !availableWindows.isEmpty {
                GroupBox("창 선택") {
                    Picker("사용 가능한 창", selection: $selectedWindowIndex) {
                        ForEach(0..<availableWindows.count, id: \.self) { index in
                            let window = availableWindows[index]
                            Text("\(window.ownerName) - \(window.name)")
                                .tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                }
            }
            
            // Captured Image Display
            if let image = capturedImage {
                GroupBox("캡처된 이미지") {
                    VStack {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 400, maxHeight: 300)
                            .border(Color.gray, width: 1)
                        
                        HStack {
                            Button("저장") {
                                showSavePanel = true
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("클립보드에 복사") {
                                copyToClipboard(image)
                            }
                            .buttonStyle(.bordered)
                            
                            Button("삭제") {
                                capturedImage = nil
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top)
                    }
                    .padding()
                }
            }
            
            // Status/Error Display
            if isCapturing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("캡처 중...")
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 600)
        .onAppear {
            checkPermissionsAndRefreshWindows()
        }
        .fileExporter(
            isPresented: $showSavePanel,
            document: capturedImage.map { ImageDocument(image: $0, options: captureOptions) },
            contentType: contentType(for: captureOptions.imageFormat),
            defaultFilename: defaultFilename()
        ) { result in
            switch result {
            case .success(let url):
                print("이미지가 저장되었습니다: \(url)")
                errorMessage = nil
            case .failure(let error):
                errorMessage = "저장 실패: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Functions
    
    private func captureFullScreen() {
        Task {
            await performCapture {
                try screenCapture.captureFullScreen(options: captureOptions)
            }
        }
    }
    
    private func captureSelectedWindow() {
        guard selectedWindowIndex < availableWindows.count else {
            errorMessage = "선택된 창이 없습니다"
            return
        }
        
        let windowID = availableWindows[selectedWindowIndex].windowID
        
        Task {
            await performCapture {
                try screenCapture.captureWindow(windowID: windowID, options: captureOptions)
            }
        }
    }
    
    private func performCapture(_ captureBlock: @escaping () throws -> NSImage) async {
        await MainActor.run {
            isCapturing = true
            errorMessage = nil
        }
        
        do {
            let image = try captureBlock()
            await MainActor.run {
                capturedImage = image
                isCapturing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isCapturing = false
            }
        }
    }
    
    private func refreshWindows() {
        availableWindows = screenCapture.getAvailableWindows()
        if selectedWindowIndex >= availableWindows.count {
            selectedWindowIndex = 0
        }
    }
    
    private func checkPermissionsAndRefreshWindows() {
        if !screenCapture.checkScreenRecordingPermission() {
            errorMessage = "스크린 녹화 권한이 필요합니다. 시스템 환경설정 > 보안 및 개인 정보 보호 > 화면 및 시스템 오디오 녹화에서 권한을 허용해주세요."
        }
        refreshWindows()
    }
    
    private func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
    
    private func contentType(for format: ScreenCapture.ImageFormat) -> UTType {
        switch format {
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        }
    }
    
    private func defaultFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        return "screenshot_\(timestamp).\(captureOptions.imageFormat.fileExtension)"
    }
}

// MARK: - ImageDocument for File Export
private struct ImageDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.png, .jpeg, .tiff]
    
    let image: NSImage
    let options: ScreenCapture.CaptureOptions
    
    init(image: NSImage, options: ScreenCapture.CaptureOptions) {
        self.image = image
        self.options = options
    }
    
    init(configuration: ReadConfiguration) throws {
        // Not used for export-only
        fatalError("Reading not supported")
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ScreenCapture.ScreenCaptureError.saveFailure("이미지 변환 실패")
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
            throw ScreenCapture.ScreenCaptureError.saveFailure("이미지 데이터 생성 실패")
        }
        
        return FileWrapper(regularFileWithContents: imageData)
    }
}

// MARK: - Preview
#Preview {
    ScreenCaptureView()
}
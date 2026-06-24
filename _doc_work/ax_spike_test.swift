#!/usr/bin/env swift
// AX 속성 가용성 사전 검증 스파이크 (Issue19 Step 0)
// 실행: swift _doc_work/ax_spike_test.swift
// 필요: Accessibility 권한 (시스템 설정 > 개인정보 보호 > 손쉬운 사용)

import ApplicationServices
import AppKit
import Foundation

// MARK: - 대상 앱 목록

let targetApps: [(name: String, bundleID: String)] = [
    ("Safari", "com.apple.Safari"),
    ("Google Chrome", "com.google.Chrome"),
    ("Finder", "com.apple.finder"),
    ("Xcode", "com.apple.dt.Xcode"),
    ("Notes", "com.apple.Notes"),
    ("Terminal", "com.apple.Terminal")
]

// MARK: - AX 유틸리티

func getAXAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    return result == .success ? value : nil
}

func getAXRole(_ element: AXUIElement) -> String? {
    guard let value = getAXAttribute(element, kAXRoleAttribute as String) else { return nil }
    return value as? String
}

func getAXFrame(_ element: AXUIElement) -> CGRect? {
    // Position
    guard let posValue = getAXAttribute(element, kAXPositionAttribute as String) else { return nil }
    var point = CGPoint.zero
    guard AXValueGetValue(posValue as! AXValue, .cgPoint, &point) else { return nil }

    // Size
    guard let sizeValue = getAXAttribute(element, kAXSizeAttribute as String) else { return nil }
    var size = CGSize.zero
    guard AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }

    return CGRect(origin: point, size: size)
}

func getAXValue(_ element: AXUIElement) -> Any? {
    return getAXAttribute(element, kAXValueAttribute as String)
}

/// 부모 체인을 탐색하여 AXScrollArea 찾기
func findScrollArea(from element: AXUIElement) -> AXUIElement? {
    var current = element
    var depth = 0
    let maxDepth = 30

    while depth < maxDepth {
        if let role = getAXRole(current), role == "AXScrollArea" {
            return current
        }
        guard let parent = getAXAttribute(current, kAXParentAttribute as String) else { break }
        current = parent as! AXUIElement
        depth += 1
    }
    return nil
}

/// 자식 요소를 재귀 탐색하여 AXScrollArea 찾기
func findScrollAreaInChildren(_ element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    if depth > 5 { return nil } // 너무 깊이 탐색 방지

    if let role = getAXRole(element), role == "AXScrollArea" {
        return element
    }

    guard let children = getAXAttribute(element, kAXChildrenAttribute as String) as? [AXUIElement] else {
        return nil
    }

    for child in children {
        if let found = findScrollAreaInChildren(child, depth: depth + 1) {
            return found
        }
    }
    return nil
}

// MARK: - 결과 구조체

struct AppResult {
    let appName: String
    let running: Bool
    let pid: pid_t?
    let hasScrollArea: Bool
    let scrollAreaFrame: CGRect?
    let hasValueAttribute: Bool
    let valueDescription: String?
    let notes: String
}

// MARK: - 메인 검증 로직

func checkAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

func testApp(_ appInfo: (name: String, bundleID: String)) -> AppResult {
    // 앱 실행 중인지 확인
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: appInfo.bundleID)
    guard let app = runningApps.first else {
        return AppResult(appName: appInfo.name, running: false, pid: nil,
                        hasScrollArea: false, scrollAreaFrame: nil,
                        hasValueAttribute: false, valueDescription: nil,
                        notes: "앱 미실행")
    }

    let pid = app.processIdentifier
    let axApp = AXUIElementCreateApplication(pid)

    // 메인 윈도우 가져오기
    guard let mainWindow = getAXAttribute(axApp, kAXMainWindowAttribute as String) else {
        return AppResult(appName: appInfo.name, running: true, pid: pid,
                        hasScrollArea: false, scrollAreaFrame: nil,
                        hasValueAttribute: false, valueDescription: nil,
                        notes: "메인 윈도우 없음")
    }

    let window = mainWindow as! AXUIElement

    // 자식 요소에서 AXScrollArea 탐색
    guard let scrollArea = findScrollAreaInChildren(window) else {
        return AppResult(appName: appInfo.name, running: true, pid: pid,
                        hasScrollArea: false, scrollAreaFrame: nil,
                        hasValueAttribute: false, valueDescription: nil,
                        notes: "AXScrollArea 미발견")
    }

    // Frame 확인
    let frame = getAXFrame(scrollArea)

    // Value 확인
    let value = getAXValue(scrollArea)
    let hasValue = value != nil
    var valueDesc: String? = nil
    if let v = value {
        valueDesc = "\(v)"
        if valueDesc!.count > 80 {
            valueDesc = String(valueDesc!.prefix(80)) + "..."
        }
    }

    // 추가 속성 확인
    var notes = ""

    // Orientation 확인
    if let orientation = getAXAttribute(scrollArea, kAXOrientationAttribute as String) as? String {
        notes += "orientation=\(orientation) "
    }

    // 자식 요소 개수
    if let children = getAXAttribute(scrollArea, kAXChildrenAttribute as String) as? [AXUIElement] {
        notes += "children=\(children.count) "
        // 스크롤바 확인
        for child in children {
            if let role = getAXRole(child) {
                if role == "AXScrollBar" {
                    if let orientation = getAXAttribute(child, kAXOrientationAttribute as String) as? String {
                        notes += "scrollbar(\(orientation)) "
                        // 스크롤바의 value 확인
                        if let sbValue = getAXValue(child) {
                            notes += "sbValue=\(sbValue) "
                        }
                    }
                }
            }
        }
    }

    return AppResult(appName: appInfo.name, running: true, pid: pid,
                    hasScrollArea: true, scrollAreaFrame: frame,
                    hasValueAttribute: hasValue, valueDescription: valueDesc,
                    notes: notes.isEmpty ? "OK" : notes)
}

// MARK: - 실행

print("=" * 70)
print("AX 속성 가용성 사전 검증 스파이크 (Issue19 Step 0)")
print("=" * 70)
print()

// Accessibility 권한 확인
if !checkAccessibilityPermission() {
    print("⚠️  Accessibility 권한이 필요합니다.")
    print("   시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 터미널/iTerm 추가")
    print()
}

// 각 앱 테스트
var results: [AppResult] = []
for appInfo in targetApps {
    let result = testApp(appInfo)
    results.append(result)
}

// 결과 출력
print("## 검증 결과")
print()
print("| 앱           | 실행 | AXScrollArea | Frame              | Value | 비고 |")
print("| :----------- | :--: | :----------: | :----------------- | :---: | :--- |")

for r in results {
    let running = r.running ? "✅" : "❌"
    let hasScroll = r.hasScrollArea ? "✅" : "❌"
    let frameStr: String
    if let f = r.scrollAreaFrame {
        frameStr = String(format: "%.0f,%.0f %.0fx%.0f", f.origin.x, f.origin.y, f.width, f.height)
    } else {
        frameStr = "-"
    }
    let hasValue = r.hasValueAttribute ? "✅" : "❌"
    print("| \(r.appName.padding(toLength: 12, withPad: " ", startingAt: 0)) | \(running)   | \(hasScroll)         | \(frameStr.padding(toLength: 18, withPad: " ", startingAt: 0)) | \(hasValue)  | \(r.notes) |")
}

print()

// 판정
let runningApps = results.filter { $0.running }
let appsWithScrollArea = results.filter { $0.hasScrollArea }
let appsWithValue = results.filter { $0.hasValueAttribute }

print("## 판정")
print("* 실행 앱: \(runningApps.count)/\(targetApps.count)")
print("* AXScrollArea 감지: \(appsWithScrollArea.count)/\(runningApps.count)")
print("* kAXValue 노출: \(appsWithValue.count)/\(runningApps.count)")
print()

if runningApps.count < 4 {
    print("⚠️  실행 중인 앱이 4개 미만. 더 많은 앱을 실행 후 재시도 권장.")
} else if appsWithValue.count * 6 < runningApps.count * 4 {
    // 4/6 이상 미노출
    print("📌 판정: kAXValue 4/6 이상 미노출 → Step 4(AX 위치 추적) 생략, Approach A로 축소")
} else {
    print("📌 판정: kAXValue 충분히 노출 → Approach B(AX 위치 추적 포함) 유지")
}

// Value 상세
if !appsWithValue.isEmpty {
    print()
    print("## Value 상세")
    for r in appsWithValue {
        print("* \(r.appName): \(r.valueDescription ?? "nil")")
    }
}

// 좌표 변환 확인
if let safariResult = results.first(where: { $0.appName == "Safari" && $0.scrollAreaFrame != nil }) {
    print()
    print("## 좌표 확인 (Safari)")
    if let frame = safariResult.scrollAreaFrame {
        print("* AX Frame: origin=(\(frame.origin.x), \(frame.origin.y)), size=(\(frame.width)x\(frame.height))")
        if let screen = NSScreen.main {
            let scale = screen.backingScaleFactor
            print("* backingScaleFactor: \(scale)")
            print("* 논리 px 좌표계 사용 확인 (AX는 항상 논리 px)")
        }
    }
}

// String * 연산자 확장
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// TDD 헬퍼 — 마우스 포인터를 최전면 일반(layer 0) 윈도우 중앙으로 옮긴다
// window_pointer 캡처 검증(tdd/playlist.md #8)이 «포인터 아래 윈도우 있음» 전제를 결정론으로 만들기 위함
// fCapture captureWindowPoint 와 같은 필터(layer 0·ownerName 비어있지 않음)를 쓴다
// 출력: 이동한 윈도우의 "owner<TAB>x,y" — 대상 윈도우가 없으면 exit 1
import CoreGraphics
import Foundation

let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    fputs("윈도우 목록을 가져올 수 없습니다\n", stderr)
    exit(1)
}

for info in list {
    guard let owner = info[kCGWindowOwnerName as String] as? String, !owner.isEmpty,
          (info[kCGWindowLayer as String] as? Int ?? 0) == 0,
          let b = info[kCGWindowBounds as String] as? [String: CGFloat],
          let x = b["X"], let y = b["Y"], let w = b["Width"], let h = b["Height"],
          w >= 100, h >= 100 else {
        continue
    }
    let center = CGPoint(x: x + w / 2, y: y + h / 2)
    CGWarpMouseCursorPosition(center)
    print("\(owner)\t\(Int(center.x)),\(Int(center.y))")
    exit(0)
}

fputs("포인터를 옮길 일반 윈도우가 없습니다\n", stderr)
exit(1)

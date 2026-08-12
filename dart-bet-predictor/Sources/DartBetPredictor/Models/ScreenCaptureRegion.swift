import AppKit
import Foundation

/// Область захвата на конкретном мониторе.
struct ScreenCaptureRegion: Equatable {
    let localRect: CGRect
    let screenIndex: Int

    static func from(localRect: CGRect, screen: NSScreen) -> ScreenCaptureRegion {
        let index = NSScreen.screens.firstIndex(of: screen) ?? 0
        return ScreenCaptureRegion(localRect: localRect, screenIndex: index)
    }

    /// CGRect для CGWindowListCreateImage (глобальные координаты, origin снизу-слева).
    func cgCaptureRect() -> CGRect {
        guard screenIndex < NSScreen.screens.count else { return localRect }
        let screen = NSScreen.screens[screenIndex]
        let frame = screen.frame
        return CGRect(
            x: frame.origin.x + localRect.origin.x,
            y: frame.origin.y + (frame.height - localRect.origin.y - localRect.height),
            width: localRect.width,
            height: localRect.height
        )
    }
}

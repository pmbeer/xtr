import AppKit
import Foundation

/// Область захвата на конкретном мониторе.
struct ScreenCaptureRegion: Equatable {
    let localRect: CGRect
    let screenIndex: Int
    /// CGDirectDisplayID — стабильнее индекса при переподключении мониторов.
    let displayID: UInt32?
    /// Снимок frame монитора при выборе области.
    let screenFrame: CGRect

    static func from(localRect: CGRect, screen: NSScreen) -> ScreenCaptureRegion {
        let index = NSScreen.screens.firstIndex(of: screen) ?? 0
        let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return ScreenCaptureRegion(
            localRect: localRect,
            screenIndex: index,
            displayID: displayNumber?.uint32Value,
            screenFrame: screen.frame
        )
    }

    /// Находит монитор по displayID или индексу.
    func resolvedScreen() -> NSScreen? {
        if let displayID {
            for screen in NSScreen.screens {
                guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                    continue
                }
                if num.uint32Value == displayID { return screen }
            }
        }
        if screenIndex < NSScreen.screens.count {
            return NSScreen.screens[screenIndex]
        }
        return NSScreen.screens.first
    }

    /// CGRect для захвата (глобальные координаты, origin снизу-слева).
    func cgCaptureRect() -> CGRect {
        guard let screen = resolvedScreen() else { return localRect }
        let frame = screen.frame
        return CGRect(
            x: frame.origin.x + localRect.origin.x,
            y: frame.origin.y + (frame.height - localRect.origin.y - localRect.height),
            width: localRect.width,
            height: localRect.height
        )
    }

    var displayIDForCapture: CGDirectDisplayID? {
        displayID.map { CGDirectDisplayID($0) }
    }
}

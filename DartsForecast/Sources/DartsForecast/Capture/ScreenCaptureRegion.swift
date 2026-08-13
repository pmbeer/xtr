import AppKit
import CoreGraphics
import Foundation

public struct ScreenCaptureRegion: Codable, Equatable, Sendable {
    /// Глобальные координаты в системе CG (origin снизу-слева).
    var cgRect: CGRect
    var displayID: CGDirectDisplayID
    var screenScale: CGFloat

    enum CodingKeys: String, CodingKey {
        case x, y, width, height, displayID, screenScale
    }

    init(cgRect: CGRect, displayID: CGDirectDisplayID, screenScale: CGFloat) {
        self.cgRect = cgRect
        self.displayID = displayID
        self.screenScale = screenScale
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let x = try c.decode(CGFloat.self, forKey: .x)
        let y = try c.decode(CGFloat.self, forKey: .y)
        let w = try c.decode(CGFloat.self, forKey: .width)
        let h = try c.decode(CGFloat.self, forKey: .height)
        cgRect = CGRect(x: x, y: y, width: w, height: h)
        displayID = CGDirectDisplayID(try c.decode(UInt32.self, forKey: .displayID))
        screenScale = try c.decode(CGFloat.self, forKey: .screenScale)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cgRect.origin.x, forKey: .x)
        try c.encode(cgRect.origin.y, forKey: .y)
        try c.encode(cgRect.size.width, forKey: .width)
        try c.encode(cgRect.size.height, forKey: .height)
        try c.encode(UInt32(displayID), forKey: .displayID)
        try c.encode(screenScale, forKey: .screenScale)
    }

    /// Локальный rect из flipped NSView (origin сверху-слева экрана) → CG.
    static func from(localRect: CGRect, screen: NSScreen) -> ScreenCaptureRegion {
        let screenFrame = screen.frame
        let scale = screen.backingScaleFactor
        // localRect в координатах окна = screen.frame в AppKit (origin снизу-слева для screen.frame,
        // но наш selector isFlipped → origin сверху-слева внутри окна).
        let appKitYFromBottom = screenFrame.height - localRect.origin.y - localRect.height
        let global = CGRect(
            x: screenFrame.origin.x + localRect.origin.x,
            y: screenFrame.origin.y + appKitYFromBottom,
            width: localRect.width,
            height: localRect.height
        )
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            ?? CGMainDisplayID()
        return ScreenCaptureRegion(cgRect: global, displayID: displayID, screenScale: scale)
    }
}

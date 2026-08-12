import AppKit
import ScreenCaptureKit

enum CaptureError: LocalizedError {
    case displayNotFound
    case notPrepared

    var errorDescription: String? {
        switch self {
        case .displayNotFound:
            return "Не найден дисплей с выбранной областью. Выберите области заново."
        case .notPrepared:
            return "Область захвата не настроена."
        }
    }
}

/// Захват маленьких областей экрана через ScreenCaptureKit.
final class ScreenGrabber {
    private struct Region {
        let filter: SCContentFilter
        let configuration: SCStreamConfiguration
    }

    private var regions: [String: Region] = [:]

    /// Готовит фильтр и конфигурацию для области `cgRect`
    /// (глобальные координаты CG, начало в левом верхнем углу основного дисплея).
    func prepare(name: String, cgRect: CGRect) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.frame.intersects(cgRect) }) else {
            throw CaptureError.displayNotFound
        }

        // Собственные окна приложения не должны попадать в кадр
        let ownApps = content.applications.filter { $0.processID == getpid() }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])

        let localRect = CGRect(x: cgRect.origin.x - display.frame.origin.x,
                               y: cgRect.origin.y - display.frame.origin.y,
                               width: cgRect.width,
                               height: cgRect.height)

        let scale = Self.backingScale(for: display)
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = localRect
        // Запрашиваем увеличенное изображение — мелкие цифры распознаются надёжнее
        configuration.width = max(1, Int(localRect.width * scale * 2))
        configuration.height = max(1, Int(localRect.height * scale * 2))
        configuration.showsCursor = false

        regions[name] = Region(filter: filter, configuration: configuration)
    }

    func capture(name: String) async throws -> CGImage {
        guard let region = regions[name] else { throw CaptureError.notPrepared }
        return try await SCScreenshotManager.captureImage(contentFilter: region.filter,
                                                          configuration: region.configuration)
    }

    private static func backingScale(for display: SCDisplay) -> CGFloat {
        for screen in NSScreen.screens {
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            if let number = screen.deviceDescription[key] as? NSNumber,
               CGDirectDisplayID(number.uint32Value) == display.displayID {
                return screen.backingScaleFactor
            }
        }
        return 2
    }
}

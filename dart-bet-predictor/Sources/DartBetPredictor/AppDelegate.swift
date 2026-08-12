import AppKit
import SwiftUI

/// Обеспечивает корректный запуск: Dock, активация, окно при старте.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchLogger.log("applicationDidFinishLaunching")

        // Показываем в Dock — пользователь видит, что приложение запустилось
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Self.showMainWindows()
        }

        NotificationCenter.default.addObserver(
            forName: .openPredictionOverlay,
            object: nil,
            queue: .main
        ) { _ in
            Self.showPredictionOverlay()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func showMainWindows() {
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        LaunchLogger.log("windows shown: \(NSApp.windows.count)")
    }

    private static func showPredictionOverlay() {
        for window in NSApp.windows where window.title.contains("Прогноз") {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            window.level = .floating
            LaunchLogger.log("Prediction overlay shown")
            return
        }
        LaunchLogger.log("Prediction overlay window not found yet")
    }
}

/// Лог запуска для диагностики (~/Library/Application Support/DartBetPredictor/launch.log).
enum LaunchLogger {
    static func log(_ message: String) {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let dir = base.appendingPathComponent("DartBetPredictor", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("launch.log")
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        if let data = line.data(using: .utf8) {
            if fm.fileExists(atPath: file.path) {
                if let handle = try? FileHandle(forWritingTo: file) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: file)
            }
        }
    }
}

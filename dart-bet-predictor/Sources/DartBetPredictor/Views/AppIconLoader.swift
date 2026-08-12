import AppKit
import SwiftUI

/// Загрузка иконки приложения для menu bar и bundle.
enum AppIconLoader {
    static var menuBarImage: NSImage? {
        if let bundled = NSImage(named: "MenuBarIcon") {
            bundled.size = NSSize(width: 18, height: 18)
            bundled.isTemplate = false
            return bundled
        }
        if let path = Bundle.main.path(forResource: "app-icon", ofType: "png"),
           let img = NSImage(contentsOfFile: path) {
            img.size = NSSize(width: 18, height: 18)
            return img
        }
        return nil
    }

    static var appIcon: NSImage? {
        NSImage(named: "AppIcon") ?? NSImage(named: "app-icon")
    }
}

struct MenuBarIconView: View {
    var body: some View {
        if let image = AppIconLoader.menuBarImage {
            Image(nsImage: image)
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "target")
                .foregroundStyle(.orange)
        }
    }
}

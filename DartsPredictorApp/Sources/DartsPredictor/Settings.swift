import CoreGraphics
import Foundation

/// CGRect в кодируемом виде (координаты CG: начало в левом верхнем углу экрана).
struct CodableRect: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.width
        height = rect.height
    }

    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

struct AppSettings: Codable, Equatable {
    var scoreLeft: CodableRect?
    var scoreRight: CodableRect?
    var pollInterval: Double = 0.15
    var voiceEnabled: Bool = true
    var oddsEven: Double = 1.85
    var oddsOdd: Double = 1.85
    var oddsLow: Double = 1.85
    var oddsHigh: Double = 1.85
    var oddsExact: Double = 12.0
    var oddsBull: Double = 15.0

    private static let storageKey = "DartsPredictorSettings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

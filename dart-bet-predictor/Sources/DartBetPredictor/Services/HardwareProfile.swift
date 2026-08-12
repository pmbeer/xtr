import Foundation

/// Профиль железа — авто-настройка под Intel Mac с 8 ГБ RAM.
enum HardwareProfile {
    static let isIntelMac: Bool = {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? ""
            }
        }
        return machine == "x86_64"
    }()

    static let isLowMemoryMac: Bool = {
        ProcessInfo.processInfo.physicalMemory <= 10 * 1024 * 1024 * 1024 // ≤10 ГБ
    }()

    /// Рекомендуемый интервал OCR (мс).
    static var recommendedPollIntervalMs: Double {
        if isIntelMac && isLowMemoryMac { return 220 }
        if isIntelMac { return 180 }
        return 150
    }

    /// Анализировать поведение игрока каждый N-й кадр.
    static var playerAnalysisStride: Int {
        if isIntelMac && isLowMemoryMac { return 3 }
        if isIntelMac { return 2 }
        return 1
    }

    /// Макс. ширина кадра для анализа движения.
    static var motionFrameWidth: Int {
        isIntelMac ? 120 : 160
    }

    static var motionFrameHeight: Int {
        isIntelMac ? 90 : 120
    }

    static var displayName: String {
        if isIntelMac && isLowMemoryMac {
            return "Intel Mac (8 ГБ) — оптимизировано"
        }
        if isIntelMac {
            return "Intel Mac"
        }
        return "Apple Silicon"
    }
}

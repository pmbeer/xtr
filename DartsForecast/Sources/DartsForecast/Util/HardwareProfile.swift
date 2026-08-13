import Foundation

/// Профиль железа под MacBook Pro 2018 / 8 GB / Intel.
enum HardwareProfile {
    /// Макс. FPS захвата области результата.
    static let resultCaptureFPS: Int = 8
    /// Макс. FPS анализа игрока.
    static let playerCaptureFPS: Int = 6
    /// Макс. ширина кадра игрока для Vision.
    static let playerMaxWidth: CGFloat = 320
    /// Кадров стабильности OCR до подтверждения броска.
    static let ocrConfirmFrames: Int = 3
    /// Минимальный интервал между подтверждёнными бросками (сек).
    static let minThrowGap: TimeInterval = 1.2
    /// Окно ставки / показа прогноза (сек).
    static let decisionWindowSeconds: Double = 5.0
    /// Макс. записей в памяти.
    static let maxHistoryInMemory: Int = 2000
    /// Сохранять каждые N бросков.
    static let autosaveEvery: Int = 1
}

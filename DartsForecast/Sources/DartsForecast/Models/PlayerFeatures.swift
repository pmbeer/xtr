import Foundation

/// Визуальные признаки игрока, извлечённые из последовательности кадров.
struct PlayerFeatures: Codable, Equatable, Sendable {
    var bodyDetected: Bool = false
    /// Наклон корпуса −1…1 (влево/вправо).
    var torsoLean: Double = 0
    /// Угол плеч −1…1.
    var shoulderAngle: Double = 0
    /// Высота поднятия руки 0…1.
    var armRaise: Double = 0
    /// Направление движения руки: −1…1.
    var armDirection: Double = 0
    /// Амплитуда замаха 0…1.
    var swingAmplitude: Double = 0
    /// Скорость движения 0…1.
    var motionSpeed: Double = 0
    /// Фаза: 0 idle, 1 aim, 2 backswing, 3 release.
    var throwPhase: Int = 0
    /// Интервал с предыдущего броска (сек).
    var intervalSeconds: Double = 0
    /// Длительность подготовки (сек).
    var prepDuration: Double = 0
    /// Хэш-ключ для группировки похожего поведения.
    var behaviorKey: String = "unknown"

    static let empty = PlayerFeatures()

    mutating func recomputeKey() {
        let leanBin = Int((torsoLean * 2).rounded())
        let armBin = Int((armRaise * 4).rounded())
        let speedBin = Int((motionSpeed * 3).rounded())
        let ampBin = Int((swingAmplitude * 3).rounded())
        behaviorKey = "L\(leanBin)_A\(armBin)_S\(speedBin)_M\(ampBin)_P\(throwPhase)"
    }
}

/// Один кадр анализа игрока (лёгкий снимок).
struct PlayerFrameSample: Sendable {
    let timestamp: Date
    let motionEnergy: Double
    let centroidY: Double
    let centroidX: Double
    let bodyDetected: Bool
}

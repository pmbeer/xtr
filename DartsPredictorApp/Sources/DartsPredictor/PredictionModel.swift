import Foundation

/// Рекомендация по ставке: рынок, вероятность по модели, коэффициент и EV.
struct Recommendation: Identifiable {
    let id = UUID()
    let market: String
    let voiceText: String
    let probability: Double
    let odds: Double

    var ev: Double { probability * odds - 1 }

    var displayText: String {
        String(format: "%@ — p=%.0f%%, кэф %.2f, EV %+.2f", market, probability * 100, odds, ev)
    }
}

/// Модель игрока: частоты секторов с экспоненциальным затуханием
/// (свежие броски весят больше — игрок мог сменить точку прицеливания)
/// и сглаживанием Лапласа (никаких нулевых вероятностей).
final class PlayerModel {
    static let bull = 25
    static let sectors: [Int] = Array(1...20) + [PlayerModel.bull]

    let decay = 0.93
    let smoothing = 0.6

    private var weights: [Int: Double]
    private(set) var history: [Int] = []

    init() {
        weights = Dictionary(uniqueKeysWithValues: Self.sectors.map { ($0, 0.0) })
    }

    func addThrow(_ sector: Int) {
        guard weights[sector] != nil else { return }
        for key in weights.keys {
            weights[key]! *= decay
        }
        weights[sector]! += 1.0
        history.append(sector)
    }

    func probabilities() -> [Int: Double] {
        let total = weights.values.reduce(0, +) + smoothing * Double(Self.sectors.count)
        return weights.mapValues { ($0 + smoothing) / total }
    }
}

/// Рекомендации по всем рынкам, отсортированные по EV (лучшая первой).
func recommend(model: PlayerModel, settings: AppSettings, topNumbers: Int = 3) -> [Recommendation] {
    let p = model.probabilities()
    var result: [Recommendation] = []

    func add(_ market: String, _ voice: String, _ probability: Double, _ odds: Double) {
        guard odds > 1 else { return }
        result.append(Recommendation(market: market, voiceText: voice,
                                     probability: probability, odds: odds))
    }

    let even = p.filter { $0.key <= 20 && $0.key % 2 == 0 }.values.reduce(0, +)
    let odd = p.filter { $0.key <= 20 && $0.key % 2 == 1 }.values.reduce(0, +)
    let low = p.filter { (1...10).contains($0.key) }.values.reduce(0, +)
    let high = p.filter { (11...20).contains($0.key) }.values.reduce(0, +)

    add("ЧЕТ", "Ставь чёт", even, settings.oddsEven)
    add("НЕЧЕТ", "Ставь нечет", odd, settings.oddsOdd)
    add("1-10", "Ставь от одного до десяти", low, settings.oddsLow)
    add("11-20", "Ставь от одиннадцати до двадцати", high, settings.oddsHigh)
    add("Буллсай", "Ставь буллсай", p[PlayerModel.bull] ?? 0, settings.oddsBull)

    let numbers = p.filter { $0.key <= 20 }.sorted { $0.value > $1.value }.prefix(topNumbers)
    for (sector, probability) in numbers {
        add("Число \(sector)", "Ставь число \(sector)", probability, settings.oddsExact)
    }

    return result.sorted { $0.ev > $1.ev }
}

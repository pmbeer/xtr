import Foundation

/// NARDBALL: ячейка 1–36 = (красная кость − 1) × 6 + синяя кость
enum DiceMath {
    static let dieFaces: Set<Int> = Set(1...6)

    static func red(from grid: Int) -> Int {
        guard grid >= 1, grid <= 36 else { return 1 }
        return ((grid - 1) / 6) + 1
    }

    static func blue(from grid: Int) -> Int {
        guard grid >= 1, grid <= 36 else { return 1 }
        return ((grid - 1) % 6) + 1
    }

    static func gridNumber(red: Int, blue: Int) -> Int {
        let r = min(6, max(1, red))
        let b = min(6, max(1, blue))
        return (r - 1) * 6 + b
    }

    static func decomposeHistory(_ history: [Int]) -> (red: [Int], blue: [Int]) {
        (history.map { red(from: $0) }, history.map { blue(from: $0) })
    }

    static func formatDice(grid: Int) -> String {
        "🔴\(red(from: grid))·🔵\(blue(from: grid))"
    }
}

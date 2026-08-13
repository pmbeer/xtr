import Foundation

struct PlayerWallet: Codable, Equatable {
    var coins: Int
    var crystals: Int

    static let empty = PlayerWallet(coins: 0, crystals: 0)

    static let maxValue = 9_999_999_999
}

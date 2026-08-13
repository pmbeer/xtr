import Foundation

struct WalletStorage {
    private let defaults: UserDefaults
    private let coinsKey = "player_coins"
    private let crystalsKey = "player_crystals"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PlayerWallet {
        PlayerWallet(
            coins: defaults.integer(forKey: coinsKey),
            crystals: defaults.integer(forKey: crystalsKey)
        )
    }

    func save(_ wallet: PlayerWallet) {
        defaults.set(wallet.coins, forKey: coinsKey)
        defaults.set(wallet.crystals, forKey: crystalsKey)
    }
}

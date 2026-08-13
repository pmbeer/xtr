import Foundation

@MainActor
final class WalletStore: ObservableObject {
    @Published private(set) var wallet: PlayerWallet

    private let storage: WalletStorage

    init(storage: WalletStorage = WalletStorage()) {
        self.storage = storage
        self.wallet = storage.load()
    }

    func setCoins(_ value: Int) {
        wallet.coins = clamp(value)
        persist()
    }

    func setCrystals(_ value: Int) {
        wallet.crystals = clamp(value)
        persist()
    }

    func setWallet(coins: Int, crystals: Int) {
        wallet = PlayerWallet(
            coins: clamp(coins),
            crystals: clamp(crystals)
        )
        persist()
    }

    func addCoins(_ amount: Int) {
        setCoins(wallet.coins + amount)
    }

    func addCrystals(_ amount: Int) {
        setCrystals(wallet.crystals + amount)
    }

    func reset() {
        wallet = .empty
        persist()
    }

    private func persist() {
        storage.save(wallet)
    }

    private func clamp(_ value: Int) -> Int {
        max(0, min(value, PlayerWallet.maxValue))
    }
}

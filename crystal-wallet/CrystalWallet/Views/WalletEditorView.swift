import SwiftUI

struct WalletEditorView: View {
    @EnvironmentObject private var walletStore: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var coinsText = ""
    @State private var crystalsText = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Монеты", text: $coinsText)
                        .keyboardType(.numberPad)

                    TextField("Кристаллы", text: $crystalsText)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Новый баланс")
                } footer: {
                    Text("Введи любое число от 0 до \(PlayerWallet.maxValue.formatted()).")
                }

                Section("Быстрые пресеты") {
                    presetButton("1 000 / 1 000", coins: 1_000, crystals: 1_000)
                    presetButton("100 000 / 100 000", coins: 100_000, crystals: 100_000)
                    presetButton("1 000 000 / 1 000 000", coins: 1_000_000, crystals: 1_000_000)
                    presetButton("Максимум", coins: PlayerWallet.maxValue, crystals: PlayerWallet.maxValue)
                }
            }
            .navigationTitle("Редактор баланса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                coinsText = String(walletStore.wallet.coins)
                crystalsText = String(walletStore.wallet.crystals)
            }
            .alert("Неверное значение", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Введи целое число от 0 до \(PlayerWallet.maxValue.formatted()).")
            }
        }
    }

    private func presetButton(_ title: String, coins: Int, crystals: Int) -> some View {
        Button(title) {
            coinsText = String(coins)
            crystalsText = String(crystals)
        }
    }

    private func save() {
        guard
            let coins = Int(coinsText.trimmingCharacters(in: .whitespaces)),
            let crystals = Int(crystalsText.trimmingCharacters(in: .whitespaces)),
            coins >= 0,
            crystals >= 0,
            coins <= PlayerWallet.maxValue,
            crystals <= PlayerWallet.maxValue
        else {
            showError = true
            return
        }

        walletStore.setWallet(coins: coins, crystals: crystals)
        dismiss()
    }
}

#Preview {
    WalletEditorView()
        .environmentObject(WalletStore())
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var walletStore: WalletStore
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.10, blue: 0.22),
                        Color(red: 0.14, green: 0.08, blue: 0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 28) {
                    header

                    VStack(spacing: 16) {
                        BalanceCard(
                            title: "Монеты",
                            value: walletStore.wallet.coins,
                            icon: "dollarsign.circle.fill",
                            accent: Color(red: 1.0, green: 0.78, blue: 0.18)
                        )

                        BalanceCard(
                            title: "Кристаллы",
                            value: walletStore.wallet.crystals,
                            icon: "diamond.fill",
                            accent: Color(red: 0.45, green: 0.82, blue: 1.0)
                        )
                    }

                    quickActions

                    Spacer()
                }
                .padding(24)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showEditor) {
                WalletEditorView()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.9))

            Text("Crystal Wallet")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Твой локальный кошелёк")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 12)
    }

    private var quickActions: some View {
        VStack(spacing: 12) {
            Button {
                showEditor = true
            } label: {
                Label("Задать баланс", systemImage: "slider.horizontal.3")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white.opacity(0.15))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            HStack(spacing: 12) {
                QuickButton(title: "+1 000", icon: "plus") {
                    walletStore.addCoins(1_000)
                    walletStore.addCrystals(1_000)
                }

                QuickButton(title: "+100 000", icon: "sparkles") {
                    walletStore.addCoins(100_000)
                    walletStore.addCrystals(100_000)
                }
            }

            Button(role: .destructive) {
                walletStore.reset()
            } label: {
                Label("Сбросить", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red.opacity(0.85))
        }
    }
}

private struct BalanceCard: View {
    let title: String
    let value: Int
    let icon: String
    let accent: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(accent)
                .frame(width: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))

                Text(value.formatted())
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(20)
        .background(.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct QuickButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.white.opacity(0.12))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WalletStore())
}

import SwiftUI

@main
struct CrystalWalletApp: App {
    @StateObject private var walletStore = WalletStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(walletStore)
        }
    }
}

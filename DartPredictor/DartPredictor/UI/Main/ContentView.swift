import SwiftUI

struct ContentView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var selectedTab = 0
    @State private var showOnboarding = false
    @State private var showResultSelector = false
    @State private var showPlayerSelector = false

    var body: some View {
        Group {
            if !settings.settings.hasCompletedOnboarding {
                OnboardingView(onComplete: {
                    settings.completeOnboarding()
                })
            } else {
                mainContent
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            HistoryManager.shared.load()
            PlayerProfileManager.shared.load()
            AccuracyManager.shared.update(from: PlayerProfileManager.shared.activeProfile)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showRegionSetup)) { _ in
            showResultSelector = true
        }
        .background {
            regionSelectors
        }
    }

    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            MainDashboardView()
                .tabItem { Label("Прогноз", systemImage: "target") }
                .tag(0)

            HistoryTabView()
                .tabItem { Label("История", systemImage: "list.bullet") }
                .tag(1)

            LearningTabView()
                .tabItem { Label("Обучение", systemImage: "brain") }
                .tag(2)

            SettingsTabView(
                showResultSelector: $showResultSelector,
                showPlayerSelector: $showPlayerSelector
            )
                .tabItem { Label("Настройки", systemImage: "gear") }
                .tag(3)
        }
        .background(PredictionOverlay())
    }

    @ViewBuilder
    private var regionSelectors: some View {
        if showResultSelector {
            RegionSelectorBridge(regionType: .result) { rect in
                showResultSelector = false
                if let rect {
                    settings.setRegion(CaptureRegion(type: .result, rect: rect))
                }
            }
        }
        if showPlayerSelector {
            RegionSelectorBridge(regionType: .player) { rect in
                showPlayerSelector = false
                if let rect {
                    settings.setRegion(CaptureRegion(type: .player, rect: rect))
                }
            }
        }
    }
}

struct SettingsTabView: View {
    @ObservedObject var settings = SettingsManager.shared
    @Binding var showResultSelector: Bool
    @Binding var showPlayerSelector: Bool

    var body: some View {
        Form {
            Section("Области экрана") {
                Button("Область результатов") { showResultSelector = true }
                Button("Область игрока") { showPlayerSelector = true }
            }

            Section("Режим") {
                Toggle("Paper Prediction", isOn: Binding(
                    get: { settings.settings.isPaperPredictionMode },
                    set: { settings.setPaperPredictionMode($0) }
                ))
                Toggle("Плавающее окно", isOn: Binding(
                    get: { settings.settings.showFloatingOverlay },
                    set: { val in
                        settings.settings.showFloatingOverlay = val
                        settings.save()
                        if val { PredictionOverlayController.shared.show() }
                        else { PredictionOverlayController.shared.hide() }
                    }
                ))
            }

            Section("Отладка") {
                Toggle("Debug логирование", isOn: Binding(
                    get: { settings.settings.debugLoggingEnabled },
                    set: { val in
                        settings.settings.debugLoggingEnabled = val
                        settings.save()
                        DebugLogger.shared.configure(enabled: val)
                    }
                ))
            }
        }
        .padding()
    }
}

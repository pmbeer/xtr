import SwiftUI

struct ContentView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var selectedTab = 0
    @State private var showMonitorSelector = false

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
        .frame(minWidth: 720, minHeight: 560)
        .onAppear {
            HistoryManager.shared.load()
            PlayerProfileManager.shared.load()
            AccuracyManager.shared.update(from: PlayerProfileManager.shared.activeProfile)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showRegionSetup)) { _ in
            showMonitorSelector = true
        }
        .background {
            if showMonitorSelector {
                RegionSelectorBridge(regionType: .gameScreen) { rect in
                    showMonitorSelector = false
                    if let rect {
                        settings.setMonitorRegion(rect)
                    }
                }
            }
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

            SettingsTabView(showMonitorSelector: $showMonitorSelector)
                .tabItem { Label("Настройки", systemImage: "gear") }
                .tag(3)
        }
        .background(PredictionOverlay())
    }
}

struct SettingsTabView: View {
    @ObservedObject var settings = SettingsManager.shared
    @Binding var showMonitorSelector: Bool

    var body: some View {
        Form {
            Section("Область мониторинга") {
                Text("Выделите область экрана с игрой — ИИ будет анализировать игрока, броски и результаты.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Выбрать игровой экран") { showMonitorSelector = true }
                if let region = settings.monitorRegion {
                    Text("Область: \(Int(region.rect.width))×\(Int(region.rect.height)) px")
                        .font(.caption)
                }
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

            Section("ИИ") {
                Text("Vision Framework + нейросеть на CPU")
                    .font(.caption)
                Text("Анализ: поза, замах, бросок, результат, игрок")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

import SwiftUI

struct ContentView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var selectedTab = 0
    @State private var showWindowPicker = false

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
        .onReceive(NotificationCenter.default.publisher(for: .showWindowPicker)) { _ in
            showWindowPicker = true
        }
        .sheet(isPresented: $showWindowPicker) {
            WindowPickerView { window in
                settings.setSelectedCaptureWindow(window)
                Task { await PipelineCoordinator.shared.testCapturePreview() }
            }
        }
    }

    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            MainDashboardView(showWindowPicker: $showWindowPicker)
                .tabItem { Label("Прогноз", systemImage: "target") }
                .tag(0)

            HistoryTabView()
                .tabItem { Label("История", systemImage: "list.bullet") }
                .tag(1)

            LearningTabView()
                .tabItem { Label("Обучение", systemImage: "brain") }
                .tag(2)

            SettingsTabView(showWindowPicker: $showWindowPicker)
                .tabItem { Label("Настройки", systemImage: "gear") }
                .tag(3)
        }
        .background(PredictionOverlay())
    }
}

struct SettingsTabView: View {
    @ObservedObject var settings = SettingsManager.shared
    @Binding var showWindowPicker: Bool

    var body: some View {
        Form {
            Section("Окно с игрой") {
                Text("Выберите окно браузера с игрой (например Safari + fon.bet). ИИ анализирует всё окно: игрок, мишень, результаты, таймер.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Выбрать окно") { showWindowPicker = true }
                if let window = settings.selectedCaptureWindow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(window.appName)
                            .font(.subheadline.weight(.semibold))
                        if !window.title.isEmpty {
                            Text(window.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(window.width)×\(window.height)")
                            .font(.caption2.monospacedDigit())
                    }
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
                Text("Анализ окна: поза, замах, бросок, OCR результатов, таймер ставки")
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

extension Notification.Name {
    static let showWindowPicker = Notification.Name("showWindowPicker")
}

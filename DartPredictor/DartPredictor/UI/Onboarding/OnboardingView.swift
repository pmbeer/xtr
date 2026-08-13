import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var step = 0
    @State private var showResultSelector = false
    @State private var showPlayerSelector = false
    @State private var ocrTestResult: String = ""
    @State private var isTestingOCR = false

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("DartPredictor")
                .font(.largeTitle.weight(.bold))

            Text(stepTitle)
                .font(.title3)
                .multilineTextAlignment(.center)

            Text(stepDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)

            stepContent

            HStack {
                if step > 0 {
                    Button("Назад") { step -= 1 }
                        .buttonStyle(.bordered)
                }

                Spacer()

                Button(step < 6 ? "Далее" : "Начать") {
                    if step < 6 {
                        step += 1
                    } else {
                        settings.completeOnboarding()
                        settings.setPaperPredictionMode(true)
                        onComplete()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed)
            }
        }
        .padding(40)
        .frame(minWidth: 560, minHeight: 420)
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Добро пожаловать"
        case 1: return "Разрешение на запис экрана"
        case 2: return "Область результатов"
        case 3: return "Область игрока"
        case 4: return "Проверка OCR"
        case 5: return "Тестовый результат"
        case 6: return "Paper Prediction"
        default: return ""
        }
    }

    private var stepDescription: String {
        switch step {
        case 0: return "Приложение анализирует область экрана с результатами дартса и поведение игрока, формирует TOP-4 прогноз следующего числа. Без автоматических ставок."
        case 1: return "Для работы необходимо разрешение на запис экрана. Откройте Системные настройки → Конфиденциальность → Запись экрана и включите DartPredictor."
        case 2: return "Выделите область, где букмекер показывает последние выпавшие числа."
        case 3: return "Выделите область с видео игрока для анализа поведения."
        case 4: return "Проверим качество распознавания чисел в выбранной области."
        case 5: return "Результат теста OCR и готовность системы."
        case 6: return "Режим Paper Prediction позволяет накопить статистику без риска — прогнозы только отображаются, ставки не выполняются."
        default: return ""
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 1:
            Button("Открыть настройки") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        case 2:
            Button("Выбрать область результатов") {
                showResultSelector = true
                RegionSelectionCoordinator.shared.present(for: .result) { rect in
                    if let rect {
                        settings.setRegion(CaptureRegion(type: .result, rect: rect))
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            if let region = settings.region(for: .result) {
                Text("Выбрано: \(Int(region.rect.width))×\(Int(region.rect.height))")
                    .font(.caption)
            }
        case 3:
            Button("Выбрать область игрока") {
                showPlayerSelector = true
                RegionSelectionCoordinator.shared.present(for: .player) { rect in
                    if let rect {
                        settings.setRegion(CaptureRegion(type: .player, rect: rect))
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            if let region = settings.region(for: .player) {
                Text("Выбрано: \(Int(region.rect.width))×\(Int(region.rect.height))")
                    .font(.caption)
            }
        case 4:
            Button("Тест OCR") { runOCRTest() }
                .buttonStyle(.borderedProminent)
                .disabled(isTestingOCR)
            if !ocrTestResult.isEmpty {
                Text(ocrTestResult)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case 5:
            VStack(spacing: 8) {
                Image(systemName: settings.region(for: .result) != nil ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.largeTitle)
                    .foregroundStyle(settings.region(for: .result) != nil ? .green : .red)
                Text(settings.region(for: .result) != nil ? "OCR область настроена" : "OCR область не настроена")
            }
        case 6:
            Toggle("Включить Paper Prediction", isOn: Binding(
                get: { settings.settings.isPaperPredictionMode },
                set: { settings.setPaperPredictionMode($0) }
            ))
        default:
            EmptyView()
        }
    }

    private var canProceed: Bool {
        switch step {
        case 2: return settings.region(for: .result) != nil
        case 3: return settings.region(for: .player) != nil
        default: return true
        }
    }

    private func runOCRTest() {
        isTestingOCR = true
        ocrTestResult = "Тест запущен — выберите область и запустите приложение для полной проверки."
        isTestingOCR = false
    }
}

struct OnboardingContainer: View {
    @State private var showResultSelector = false
    @State private var showPlayerSelector = false
    let onComplete: () -> Void

    var body: some View {
        OnboardingView(onComplete: onComplete)
            .background {
                if showResultSelector {
                    RegionSelectorBridge(regionType: .result) { rect in
                        showResultSelector = false
                        if let rect {
                            SettingsManager.shared.setRegion(CaptureRegion(type: .result, rect: rect))
                        }
                    }
                }
                if showPlayerSelector {
                    RegionSelectorBridge(regionType: .player) { rect in
                        showPlayerSelector = false
                        if let rect {
                            SettingsManager.shared.setRegion(CaptureRegion(type: .player, rect: rect))
                        }
                    }
                }
            }
    }
}

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var step = 0

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
                .frame(maxWidth: 520)

            stepContent

            HStack {
                if step > 0 {
                    Button("Назад") { step -= 1 }
                        .buttonStyle(.bordered)
                }

                Spacer()

                Button(step < 4 ? "Далее" : "Начать") {
                    if step < 4 {
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
        .frame(minWidth: 580, minHeight: 440)
    }

    private var stepTitle: String {
        switch step {
        case 0: return "ИИ наблюдает ваш экран"
        case 1: return "Разрешение на запис экрана"
        case 2: return "Выбор области игры"
        case 3: return "Как работает ИИ"
        case 4: return "Paper Prediction"
        default: return ""
        }
    }

    private var stepDescription: String {
        switch step {
        case 0: return "Выделите область экрана с игрой в дартс. ИИ анализирует всё: кто бросает, как бросает, результаты. Формирует комбинацию 4 чисел для следующего броска."
        case 1: return "Откройте Системные настройки → Конфиденциальность → Запись экрана и включите DartPredictor."
        case 2: return "Выделите область, где видны игрок, мишень/стрим и результаты бросков."
        case 3: return "ИИ использует Vision (поза, движение) и нейросеть на CPU. Распознаёт фазы: подготовка → замах → бросок → результат. Обучается после каждого броска."
        case 4: return "Paper Prediction — прогнозы только на экране, без ставок. Накопите статистику без риска."
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
            Button("Выбрать область экрана") {
                RegionSelectionCoordinator.shared.present(for: .gameScreen) { rect in
                    if let rect {
                        settings.setMonitorRegion(rect)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            if let region = settings.monitorRegion {
                Text("Выбрано: \(Int(region.rect.width))×\(Int(region.rect.height)) px")
                    .font(.caption)
            }
        case 3:
            VStack(alignment: .leading, spacing: 6) {
                Label("Распознавание игрока и позы", systemImage: "figure.handball")
                Label("Анализ замаха и броска", systemImage: "arrow.up.forward")
                Label("OCR результатов на экране", systemImage: "number")
                Label("Прогноз комбинации TOP-4", systemImage: "brain")
            }
            .font(.caption)
        case 4:
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
        case 2: return settings.monitorRegion != nil
        default: return true
        }
    }
}

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var step = 0
    @State private var showWindowPicker = false

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
        .sheet(isPresented: $showWindowPicker) {
            WindowPickerView { window in
                settings.setSelectedCaptureWindow(window)
                Task { await PipelineCoordinator.shared.testCapturePreview() }
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return "ИИ наблюдает окно с игрой"
        case 1: return "Разрешение на запис экрана"
        case 2: return "Выбор окна с игрой"
        case 3: return "Как работает ИИ"
        case 4: return "Paper Prediction"
        default: return ""
        }
    }

    private var stepDescription: String {
        switch step {
        case 0: return "Откройте NARDBALL (fon.bet). ИИ читает историю костей в верхней полосе и математически предлагает 4 варианта комбинации на сетке 1–36."
        case 1: return "Откройте Системные настройки → Конфиденциальность → Запись экрана и включите DartPredictor."
        case 2: return "Выберите окно с NARDBALL. Калибруйте зону «История» на верхнюю полосу с числами и костями."
        case 3: return "Модель DiceMath анализирует красную и синюю кость отдельно, строит переходы и выдает TOP-4 + 4 комбинации с минимизацией ошибки."
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
            Button("Выбрать окно Safari / fon.bet") {
                showWindowPicker = true
            }
            .buttonStyle(.borderedProminent)
            if let window = settings.selectedCaptureWindow {
                Text("Выбрано: \(window.displayTitle)")
                    .font(.caption)
            }
        case 3:
            VStack(alignment: .leading, spacing: 6) {
                Label("Захват окна браузера", systemImage: "macwindow")
                Label("Распознавание игрока и позы", systemImage: "figure.handball")
                Label("OCR результатов и таймера", systemImage: "number")
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
        case 2: return settings.selectedCaptureWindow != nil
        default: return true
        }
    }
}

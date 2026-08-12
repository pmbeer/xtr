import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                recommendationCard
                learningCard
                captureControls
                calibrationControls
                diagnostics
            }
            .padding(20)
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 860)
        .task {
            await model.refreshWindows()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Darts Assistant")
                    .font(.title2.bold())
                Text(model.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(model.isCapturing ? Color.green : Color.secondary)
                .frame(width: 10, height: 10)
            Text(model.isCapturing ? "LIVE" : "STOP")
                .font(.caption.monospaced().bold())
        }
    }

    private var recommendationCard: some View {
        VStack(spacing: 8) {
            Text("СЛЕДУЮЩАЯ СТАВКА")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(model.recommendation.title)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    model.recommendation.candidate == nil ? Color.orange : Color.green
                )
            Text(model.recommendation.detail)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack {
                Label(
                    model.latestThrow.map { "Бросок: \($0)" } ?? "Бросок: —",
                    systemImage: "scope"
                )
                Label("\(model.sampleCount) в выборке", systemImage: "chart.bar")
                Label("\(model.latencyMilliseconds) мс", systemImage: "bolt")
            }
            .font(.caption.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var learningCard: some View {
        GroupBox("Online-обучение и поведение") {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Следующий сектор:")
                    Text(model.learningMetrics.predictedNumber.map(String.init) ?? "—")
                        .font(.title2.bold().monospacedDigit())
                    Text("уверенность \(percent(model.learningMetrics.confidence))")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(
                        model.learningMetrics.lastPredictionWasCorrect.map {
                            $0 ? "прошлый ✓" : "прошлый ✕"
                        } ?? "нет проверки"
                    )
                    .foregroundStyle(
                        model.learningMetrics.lastPredictionWasCorrect == true
                            ? Color.green : Color.secondary
                    )
                }

                HStack {
                    metric(
                        "Точность всего",
                        model.learningMetrics.totalAccuracy.map(percent) ?? "—"
                    )
                    metric(
                        "Последние 100",
                        model.learningMetrics.rollingAccuracy.map(percent) ?? "—"
                    )
                    metric(
                        "Проверено",
                        "\(model.learningMetrics.evaluatedCount)"
                    )
                    metric(
                        "Поза",
                        percent(model.learningMetrics.behaviorConfidence)
                    )
                }

                Text(
                    "Точность считается честно: сначала фиксируется прогноз, затем "
                        + "приходит исход, прогноз проверяется и только после этого модель учится. "
                        + "99% — не обещание; приложение показывает фактически достигнутый результат."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private var captureControls: some View {
        GroupBox("Захват окна") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Picker("Окно", selection: $model.selectedWindowID) {
                        Text("Не выбрано").tag(CGWindowID?.none)
                        ForEach(model.windows, id: \.windowID) { window in
                            Text(model.windowLabel(window))
                                .tag(Optional(window.windowID))
                        }
                    }
                    .disabled(model.isCapturing || model.isTransitioning)
                    Button {
                        Task { await model.refreshWindows() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Обновить список окон")
                    .disabled(model.isCapturing || model.isTransitioning)
                }

                HStack {
                    Button(model.isCapturing ? "Остановить" : "Начать анализ") {
                        Task { await model.toggleCapture() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isTransitioning)

                    Button("Сбросить статистику") {
                        model.resetStatistics()
                    }

                    Button("Стереть обучение") {
                        model.eraseLearning()
                    }
                    .foregroundStyle(.red)

                    Toggle("Голос", isOn: $model.voiceEnabled)
                    Spacer()
                    Button("Доступ к экрану…") {
                        openScreenRecordingSettings()
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var calibrationControls: some View {
        VStack(spacing: 12) {
            GroupBox("Область истории бросков") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(
                        "Оставьте в области только ячейки истории (минимум 5). "
                            + "Меняйте ползунки, пока OCR ниже не покажет числа."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    regionSlider("X", value: $model.region.x)
                    regionSlider("Y", value: $model.region.y)
                    regionSlider("Ширина", value: $model.region.width)
                    regionSlider("Высота", value: $model.region.height)

                    Toggle(
                        "Новейший результат распознаётся первым",
                        isOn: $model.newestFirst
                    )
                }
                .padding(.top, 4)
            }

            GroupBox("Область игрока / ведущего") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(
                        "Обведите человека целиком. Vision извлекает только координаты "
                            + "плеч, локтей, кистей и головы; изображение не сохраняется."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    regionSlider("X", value: $model.behaviorRegion.x)
                    regionSlider("Y", value: $model.behaviorRegion.y)
                    regionSlider("Ширина", value: $model.behaviorRegion.width)
                    regionSlider("Высота", value: $model.behaviorRegion.height)
                }
                .padding(.top, 4)
            }
        }
        .disabled(model.isCapturing || model.isTransitioning)
    }

    private var diagnostics: some View {
        GroupBox("Диагностика OCR") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Числа: \(model.recognizedValues.map(String.init).joined(separator: ", "))")
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                Text("Текст: \(model.rawOCR)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(
                    "Подсказка не гарантирует выигрыш. Ставка показывается только при "
                        + "статистически заметном отклонении; без него безопасный ответ — пропуск."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private func regionSlider(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
                .frame(width: 65, alignment: .leading)
            Slider(value: value, in: 0...1, step: 0.01)
            Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
                .font(.caption.monospacedDigit())
                .frame(width: 36)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold().monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)))
    }

    private func openScreenRecordingSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security"
                + "?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}

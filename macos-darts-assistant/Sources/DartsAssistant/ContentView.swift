import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                recommendationCard
                captureControls
                calibrationControls
                diagnostics
            }
            .padding(20)
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 700)
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
        GroupBox("Область истории бросков") {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    "Оставьте в области только ячейки истории (минимум 5). "
                        + "Меняйте ползунки, пока OCR ниже не покажет числа в нужном порядке."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                regionSlider("X", value: $model.region.x)
                regionSlider("Y", value: $model.region.y)
                regionSlider("Ширина", value: $model.region.width)
                regionSlider("Высота", value: $model.region.height)

                Toggle("Новейший результат распознаётся первым", isOn: $model.newestFirst)
            }
            .padding(.top, 4)
            .disabled(model.isCapturing || model.isTransitioning)
        }
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

    private func openScreenRecordingSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security"
                + "?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}

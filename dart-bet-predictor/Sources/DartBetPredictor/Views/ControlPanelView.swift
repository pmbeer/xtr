import AppKit
import SwiftUI

struct ControlPanelView: View {
    @EnvironmentObject var coordinator: MonitorCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            statusSection
            regionSection
            strategySection
            controlsSection
            metricsSection
            historySection
            disclaimer
        }
        .padding(16)
        .frame(width: 360)
    }

    private var header: some View {
        HStack {
            Image(systemName: "target")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dart Bet Predictor")
                    .font(.headline)
                Text("FONBET Дартс 24/7")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(coordinator.isRunning ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
        }
    }

    private var statusSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(coordinator.statusMessage)
                    .font(.subheadline)
                    .lineLimit(2)

                if let rec = coordinator.currentRecommendation {
                    HStack {
                        Text("Ставка:")
                            .foregroundStyle(.secondary)
                        Text(rec.displayBet)
                            .font(.title2.bold())
                            .foregroundStyle(.orange)
                        Spacer()
                        Text("\(rec.confidencePercent)%")
                            .font(.caption.monospacedDigit())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Text(rec.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                phaseIndicator
            }
        }
    }

    @ViewBuilder
    private var phaseIndicator: some View {
        switch coordinator.phase {
        case .idle:
            EmptyView()
        case .waitingForThrow:
            Label("Ожидание броска…", systemImage: "hourglass")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .bettingOpen(let remaining, let rec):
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(.red)
                Text(String(format: "СТАВКА: %@ — %.1f сек", rec.displayBet, remaining))
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
            ProgressView(value: remaining, total: coordinator.bettingWindowSeconds)
                .tint(.red)
        }
    }

    private var regionSection: some View {
        GroupBox("Область захвата") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Выделите панель «СЕРИЯ» с историей бросков (справа внизу на экране игры).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let region = coordinator.captureRegion {
                    Text(String(format: "%.0f × %.0f px", region.width, region.height))
                        .font(.caption.monospacedDigit())
                }

                Button("Выбрать область экрана") {
                    RegionSelectorWindowController.present { rect in
                        coordinator.setCaptureRegion(rect)
                    }
                }
            }
        }
    }

    private var strategySection: some View {
        GroupBox("Стратегия") {
            Picker("Стратегия", selection: $coordinator.strategy) {
                ForEach(PredictionStrategy.allCases) { strategy in
                    Text(strategy.displayName).tag(strategy)
                }
            }
            .labelsHidden()

            HStack {
                Text("Окно ставки")
                Slider(value: $coordinator.bettingWindowSeconds, in: 3...8, step: 0.5)
                Text(String(format: "%.0fс", coordinator.bettingWindowSeconds))
                    .font(.caption.monospacedDigit())
                    .frame(width: 28)
            }

            HStack {
                Text("Скорость OCR")
                Slider(value: $coordinator.pollIntervalMs, in: 80...400, step: 20)
                Text(String(format: "%.0fмс", coordinator.pollIntervalMs))
                    .font(.caption.monospacedDigit())
                    .frame(width: 40)
            }
        }
    }

    private var controlsSection: some View {
        HStack {
            if coordinator.isRunning {
                Button("Стоп") { coordinator.stop() }
                    .keyboardShortcut(.cancelAction)
            } else {
                Button("Старт") { coordinator.start() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(coordinator.captureRegion == nil)
            }

            Button("Сброс") { coordinator.resetHistory() }

            Spacer()

            Button("Разрешения") {
                coordinator.requestScreenPermission()
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                )
            }
            .font(.caption)
        }
    }

    private var metricsSection: some View {
        GroupBox("Производительность") {
            HStack {
                metric("OCR", String(format: "%.0f мс", coordinator.parseLatencyMs))
                metric("FPS", String(format: "%.1f", coordinator.fps))
                metric("История", "\(coordinator.throwTracker.history.count)")
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().bold())
        }
        .frame(maxWidth: .infinity)
    }

    private var historySection: some View {
        GroupBox("Последние броски") {
            if coordinator.throwTracker.history.isEmpty {
                Text("Нет данных")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(coordinator.throwTracker.history.prefix(20).enumerated()), id: \.offset) { _, sector in
                            Text(sector.description)
                                .font(.caption.bold())
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(.orange.opacity(0.25)))
                        }
                    }
                }
            }
        }
    }

    private var disclaimer: some View {
        Text("⚠️ Прогнозы статистические. Азартные игры — риск потери средств. Приложение не гарантирует выигрыш.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

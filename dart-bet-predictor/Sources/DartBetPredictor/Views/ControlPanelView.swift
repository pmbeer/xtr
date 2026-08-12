import AppKit
import SwiftUI

struct ControlPanelView: View {
    @EnvironmentObject var coordinator: MonitorCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            statusSection
            pipelineSection
            learningSection
            regionSection
            playerBehaviorSection
            strategySection
            controlsSection
            metricsSection
            outcomesSection
            historySection
            disclaimer
        }
        .padding(16)
        .frame(minWidth: 400, minHeight: 480)
    }

    private var header: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dart Bet Predictor")
                    .font(.headline)
                Text("FONBET Дартс 24/7 · \(HardwareProfile.displayName)")
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
                    .lineLimit(3)

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

    private var pipelineSection: some View {
        GroupBox("Пайплайн анализа") {
            PipelineStatusView(
                currentStep: coordinator.pipelineStep,
                isRunning: coordinator.isRunning
            )
            if coordinator.isRunning {
                Label(coordinator.pipelineStep.displayName, systemImage: coordinator.pipelineStep.icon)
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
        }
    }

    private var learningSection: some View {
        GroupBox("Система обучения → 99%") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Точность (50 бросков)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(coordinator.learningEngine.stats.recentAccuracyPercent)%")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(accuracyColor)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Цель")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("99%")
                            .font(.title3.bold())
                            .foregroundStyle(.green)
                    }
                }

                ProgressView(value: coordinator.learningEngine.stats.progressToTarget)
                    .tint(accuracyColor)

                HStack(spacing: 12) {
                    Label(coordinator.learningEngine.stats.learningPhase, systemImage: "brain")
                        .font(.caption2)
                    Label(coordinator.learningEngine.stats.streakDisplay, systemImage: "flame")
                        .font(.caption2)
                    Spacer()
                    Text("LR \(String(format: "%.2f", coordinator.learningEngine.stats.adaptiveLearningRate))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Всего: \(coordinator.learningEngine.stats.totalPredictions)")
                    Spacer()
                    Text("Верных: \(coordinator.learningEngine.stats.correctPredictions)")
                    Spacer()
                    Text("Итераций: \(coordinator.learningEngine.stats.learningIterations)")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

                Text(coordinator.learningEngine.lastLearningMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var accuracyColor: Color {
        let acc = coordinator.learningEngine.stats.recentAccuracy
        if acc >= 0.7 { return .green }
        if acc >= 0.45 { return .orange }
        return .red
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
        GroupBox("Область «СЕРИЯ» (исход броска)") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Выделите панель с кружками-номерами истории бросков.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                regionButton(
                    label: "Выбрать СЕРИЮ",
                    configured: coordinator.seriesRegion != nil
                ) {
                    RegionSelectorWindowController.present(title: "Выделите панель СЕРИЯ") { rect in
                        coordinator.setSeriesRegion(rect)
                    }
                }
            }
        }
    }

    private var playerBehaviorSection: some View {
        GroupBox("Область «Игрок» (поведение)") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Выделите видео с игроком/ведущим (правая часть экрана).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                regionButton(
                    label: "Выбрать игрока",
                    configured: coordinator.playerRegion != nil
                ) {
                    RegionSelectorWindowController.present(title: "Выделите видео игрока") { rect in
                        coordinator.setPlayerRegion(rect)
                    }
                }

                HStack {
                    Image(systemName: "figure.stand")
                        .foregroundStyle(.blue)
                    Text(coordinator.currentPlayerBehavior.summary)
                        .font(.caption)
                }
            }
        }
    }

    private func regionButton(label: String, configured: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Button(label, action: action)
            if configured {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
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
                    .disabled(coordinator.seriesRegion == nil)
            }

            Button("Сброс") { coordinator.resetHistory() }
            Button("Сброс обучения") { coordinator.resetLearning() }
                .font(.caption)

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
                metric("Поведение", String(format: "%.0f мс", coordinator.behaviorLatencyMs))
                metric("FPS", String(format: "%.1f", coordinator.fps))
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

    private var outcomesSection: some View {
        GroupBox("Последние прогнозы") {
            if coordinator.learningEngine.recentOutcomes.isEmpty {
                Text("Прогнозы появятся после 2-го броска")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(coordinator.learningEngine.recentOutcomes.prefix(5)) { outcome in
                    HStack(spacing: 6) {
                        Text(outcome.displayResult)
                            .font(.caption.bold())
                            .foregroundStyle(outcome.wasCorrect ? .green : .red)
                        Text("→ \(outcome.actualSector)")
                            .font(.caption.monospacedDigit())
                        Spacer()
                        Text(outcome.betType.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
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
        Text("⚠️ Обучение повышает точность на повторяющихся паттернах, но не гарантирует 99% при случайных бросках. Азартные игры — риск.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

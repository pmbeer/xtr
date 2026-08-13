import AppKit
import SwiftUI

struct ControlPanelView: View {
    @EnvironmentObject var coordinator: MonitorCoordinator
    @Environment(\.openWindow) private var openWindow

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
        .onReceive(NotificationCenter.default.publisher(for: .openPredictionOverlay)) { _ in
            openWindow(id: "prediction-overlay")
        }
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
                        Text("4 прогноза:")
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
                    if rec.displayNumbers.count >= 2 {
                        HStack(spacing: 8) {
                            ForEach(rec.displayNumbers, id: \.self) { n in
                                Text("\(n)")
                                    .font(.headline.bold().monospacedDigit())
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(.orange.opacity(0.25)))
                            }
                        }
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
            Label("Ожидание броска игрока…", systemImage: "hourglass")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .awaitingResult(let pending, let stable, let required):
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundStyle(.blue)
                if let pending {
                    Text("Ждём результат: \(pending.description) (\(stable)/\(required))")
                        .font(.caption.bold())
                } else {
                    Text("Ждём результат на экране…")
                        .font(.caption.bold())
                }
            }
        case .bettingOpen(let remaining, let rec, let confirmed):
            VStack(alignment: .leading, spacing: 4) {
                Text("Выпало: \(confirmed.description) → ставка на следующий: \(rec.displayBet)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Image(systemName: "timer")
                        .foregroundStyle(.red)
                    Text(String(format: "СТАВКА — %.1f сек", remaining))
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
                ProgressView(value: remaining, total: coordinator.bettingWindowSeconds)
                    .tint(.red)
            }
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
                    RegionSelectorWindowController.present(title: "Выделите панель СЕРИЯ") { region in
                        coordinator.setSeriesRegion(region)
                    }
                }

                if let preview = coordinator.seriesPreview {
                    previewImage(preview, label: "Захват СЕРИЯ")
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
                    RegionSelectorWindowController.present(title: "Выделите видео игрока") { region in
                        coordinator.setPlayerRegion(region)
                    }
                }

                HStack {
                    Image(systemName: coordinator.currentPlayerBehavior.bodyDetected ? "figure.stand" : "figure.walk.motion")
                        .foregroundStyle(coordinator.currentPlayerBehavior.bodyDetected ? .blue : .orange)
                    Text(coordinator.currentPlayerBehavior.summary)
                        .font(.caption)
                }

                if coordinator.isRunning {
                    Text("Кадры игрока: \(coordinator.playerCaptureSuccessCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let preview = coordinator.playerPreview {
                    previewImage(preview, label: "Захват игрока")
                }
            }
        }
    }

    private func previewImage(_ image: NSImage, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 80)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.orange.opacity(0.5), lineWidth: 1))
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
                Slider(value: $coordinator.bettingWindowSeconds, in: 6...15, step: 0.5)
                Text(String(format: "%.0fс", coordinator.bettingWindowSeconds))
                    .font(.caption.monospacedDigit())
                    .frame(width: 28)
            }
            if let timer = coordinator.detectedTimerSeconds {
                Text("Таймер на экране: \(String(format: "%.1f", timer))с")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.blue)
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
        GroupBox("Производительность и диагностика") {
            HStack {
                metric("OCR", String(format: "%.0f мс", coordinator.parseLatencyMs))
                metric("Поведение", String(format: "%.0f мс", coordinator.behaviorLatencyMs))
                metric("FPS", String(format: "%.1f", coordinator.fps))
            }

            if coordinator.isRunning {
                Divider()
                HStack {
                    metric("Секторов", "\(coordinator.lastSectorCount)")
                    metric("СЕРИЯ OK", "\(coordinator.captureSuccessCount)")
                    metric("Игрок OK", "\(coordinator.playerCaptureSuccessCount)")
                }
                HStack {
                    metric("Метод", coordinator.captureMethod)
                    metric("Ошибки", "\(coordinator.captureFailureCount)")
                }
                if let path = coordinator.sessionRecordingPath {
                    Text("Запись: \(path)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if !coordinator.lastOCRTexts.isEmpty {
                    Text("OCR: \(coordinator.lastOCRTexts.joined(separator: ", "))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if coordinator.captureSuccessCount > 0 {
                    Text("OCR: нет чисел — расширьте область СЕРИЯ")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if coordinator.visualChangeScore > 0.15 {
                    Label("Визуальное изменение \(Int(coordinator.visualChangeScore * 100))%", systemImage: "eye")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
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
                        if !outcome.predictedNumbers.isEmpty {
                            Text("[\(outcome.displayPrediction)]")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
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

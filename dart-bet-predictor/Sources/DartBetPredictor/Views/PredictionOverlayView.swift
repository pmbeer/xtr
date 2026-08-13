import SwiftUI

/// Плавающее окно с крупной рекомендацией ставки, таймером и статусом обучения.
struct PredictionOverlayView: View {
    @EnvironmentObject var coordinator: MonitorCoordinator

    var body: some View {
        VStack(spacing: 12) {
            learningBadge

            switch coordinator.phase {
            case .idle:
                idleView
            case .waitingForThrow:
                waitingView
            case .awaitingResult(let pending, let stable, let required):
                awaitingResultView(pending: pending, stable: stable, required: required)
            case .bettingOpen(let remaining, let recommendation, let confirmed):
                bettingView(remaining: remaining, recommendation: recommendation, confirmed: confirmed)
            }
        }
        .padding(20)
        .frame(minWidth: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 12)
        )
        .floatingWindow()
    }

    private var pipelineRow: some View {
        HStack(spacing: 4) {
            Image(systemName: coordinator.pipelineStep.icon)
                .font(.caption2)
            Text(coordinator.pipelineStep.displayName)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
    }

    private var learningBadge: some View {
        HStack {
            Image(systemName: "brain")
                .font(.caption)
            Text("Обучение: \(coordinator.learningEngine.stats.recentAccuracyPercent)%")
                .font(.caption.bold().monospacedDigit())
            Spacer()
            Text("→ 99%")
                .font(.caption2)
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(.blue.opacity(0.15)))
    }

    private var idleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "target")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Dart Bet Predictor")
                .font(.headline)
            Text("Запустите мониторинг")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var waitingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Ожидание броска игрока…")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let last = coordinator.lastDetectedThrow {
                Text("Последний результат: \(last.sector.description)")
                    .font(.caption)
            }

            if let outcome = coordinator.lastOutcome {
                Text("\(outcome.displayResult) — выпало \(outcome.actualSector)")
                    .font(.caption.bold())
                    .foregroundStyle(outcome.wasCorrect ? .green : .red)
            }

            Text(coordinator.currentPlayerBehavior.summary)
                .font(.caption2)
                .foregroundStyle(.secondary)

            pipelineRow
        }
    }

    private func awaitingResultView(pending: DartSector?, stable: Int, required: Int) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.badge.checkmark")
                .font(.largeTitle)
                .foregroundStyle(.blue)
            Text("Ждём результат броска")
                .font(.headline)
            if let pending {
                Text("\(pending.description)")
                    .font(.title.bold())
                    .foregroundStyle(.orange)
            }
            Text("Подтверждение \(stable)/\(required)")
                .font(.caption.monospacedDigit())
            Text(coordinator.currentPlayerBehavior.summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
            pipelineRow
        }
    }

    private func bettingView(remaining: Double, recommendation: BetRecommendation, confirmed: DartSector) -> some View {
        VStack(spacing: 10) {
            Text("Выпало: \(confirmed.description)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text("СТАВКА НА СЛЕДУЮЩИЙ!")
                .font(.caption.bold())
                .foregroundStyle(.red)

            if recommendation.displayNumbers.count >= 2 {
                HStack(spacing: 12) {
                    ForEach(recommendation.displayNumbers, id: \.self) { n in
                        Text("\(n)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.orange)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(.orange.opacity(0.2)))
                    }
                }
            } else {
                Text(recommendation.displayBet)
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(.orange)
            }

            Text(recommendation.betType.displayName)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(String(format: "%.1f сек", remaining))
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(remaining < 2 ? .red : .primary)

            ProgressView(value: remaining, total: coordinator.bettingWindowSeconds)
                .tint(.red)
                .scaleEffect(y: 2)

            HStack {
                Text("\(recommendation.confidencePercent)%")
                    .font(.caption.bold())
                Text(recommendation.reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if coordinator.currentPlayerBehavior.bodyDetected {
                Label(coordinator.currentPlayerBehavior.phase.displayName, systemImage: "figure.stand")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: remaining)
    }
}

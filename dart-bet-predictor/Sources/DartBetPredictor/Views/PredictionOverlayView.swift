import SwiftUI

/// Плавающее окно с крупной рекомендацией ставки и таймером.
struct PredictionOverlayView: View {
    @EnvironmentObject var coordinator: MonitorCoordinator

    var body: some View {
        VStack(spacing: 12) {
            switch coordinator.phase {
            case .idle:
                idleView
            case .waitingForThrow:
                waitingView
            case .bettingOpen(let remaining, let recommendation):
                bettingView(remaining: remaining, recommendation: recommendation)
            }
        }
        .padding(20)
        .frame(minWidth: 280)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 12)
        )
        .floatingWindow()
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
            Text("Ожидание броска…")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let last = coordinator.lastDetectedThrow {
                Text("Последний: \(last.sector.description)")
                    .font(.caption)
            }
        }
    }

    private func bettingView(remaining: Double, recommendation: BetRecommendation) -> some View {
        VStack(spacing: 10) {
            Text("СТАВКА!")
                .font(.caption.bold())
                .foregroundStyle(.red)

            Text(recommendation.displayBet)
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(.orange)
                .contentTransition(.numericText())

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
        }
        .animation(.easeInOut(duration: 0.15), value: remaining)
    }
}

import SwiftUI

/// Визуализация пайплайна: исход → поведение → обучение → прогноз.
struct PipelineStatusView: View {
    let currentStep: AnalysisPipelineStep
    let isRunning: Bool

    var body: some View {
        if isRunning {
            VStack(alignment: .leading, spacing: 6) {
                Text("Анализ в реальном времени")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    ForEach(AnalysisPipelineStep.allCases.filter { $0 != .idle }, id: \.self) { step in
                        pipelineChip(step)
                    }
                }
            }
        }
    }

    private func pipelineChip(_ step: AnalysisPipelineStep) -> some View {
        let active = step == currentStep
        let passed = stepOrder(step) < stepOrder(currentStep)

        return HStack(spacing: 3) {
            Image(systemName: step.icon)
                .font(.caption2)
            if active {
                Text(step.displayName)
                    .font(.caption2.bold())
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(active ? Color.orange.opacity(0.35) : (passed ? Color.green.opacity(0.2) : Color.gray.opacity(0.15)))
        )
        .foregroundStyle(active ? .orange : (passed ? .green : .secondary))
    }

    private func stepOrder(_ step: AnalysisPipelineStep) -> Int {
        switch step {
        case .idle: return 0
        case .watchingOutcome: return 1
        case .analyzingBehavior: return 2
        case .awaitingResult: return 3
        case .evaluatingPrediction: return 4
        case .learning: return 5
        case .generatingForecast: return 6
        }
    }
}

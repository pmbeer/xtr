import SwiftUI
import AppKit

struct LivePreviewPanel: View {
    let image: CGImage?
    let cropSize: CGSize
    let captureFrames: Int
    var captureBackend: String = "—"
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Область игры (live)", systemImage: "rectangle.dashed.badge.record")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(captureBackend) · \(captureFrames) кадров · \(Int(cropSize.width))×\(Int(cropSize.height))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let img = image {
                Image(decorative: img, scale: 1.0)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.5), lineWidth: 1))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 80)
                    .overlay {
                        Text("Нет кадра — проверьте область и разрешение")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AIStatusPanel: View {
    let phase: GamePhase
    let sceneState: GameSceneState
    let insight: AIActionInsight
    let detectedNumbers: [Int]
    let bettingSeconds: Double?
    let throwInProgress: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ИИ-анализ", systemImage: "brain.head.profile")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                Label(phase.rawValue, systemImage: phase.icon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(phaseColor)

                if throwInProgress {
                    Label("Бросок", systemImage: "figure.handball")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                }

                if let sec = bettingSeconds {
                    Label("\(String(format: "%.1f", sec))с", systemImage: "timer")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.blue)
                }
            }

            Text(insight.aiDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if !detectedNumbers.isEmpty {
                Text("Результаты на экране: \(detectedNumbers.map(String.init).joined(separator: ", "))")
                    .font(.caption.monospacedDigit())
            }

            ProgressView(value: insight.throwPhaseProgress) {
                Text("Фаза броска · \(insight.detectedAction.rawValue)")
                    .font(.caption2)
            }
            .tint(.orange)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var phaseColor: Color {
        switch phase {
        case .bettingWindow: return .blue
        case .throwing: return .orange
        case .resultShown: return .green
        default: return .secondary
        }
    }
}

struct CombinationDisplayView: View {
    let combination: PredictedCombination

    var body: some View {
        if !combination.numbers.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("КОМБИНАЦИЯ")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(combination.formatted)
                    .font(.title2.weight(.bold).monospacedDigit())

                HStack {
                    Text("Совместная вероятность:")
                        .font(.caption)
                    Text(String(format: "%.1f%%", combination.jointProbability))
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
            }
        }
    }
}

struct PredictionDisplayView: View {
    let predictions: [TopPrediction]
    let combination: PredictedCombination
    let confidence: ConfidenceLevel
    let confidenceScore: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("СЛЕДУЮЩИЙ ПРОГНОЗ")
                .font(.headline)
                .foregroundStyle(.secondary)

            CombinationDisplayView(combination: combination)

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(predictions) { pred in
                        Text("# \(pred.number)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(predictions) { pred in
                        Text("\(pred.number) — \(String(format: "%.1f", pred.probability))%")
                            .font(.title3)
                            .monospacedDigit()
                    }
                }
            }

            HStack {
                Text("Уверенность: \(confidence.localizedName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(confidenceColor)

                Spacer()

                Text("\(Int(confidenceScore))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var confidenceColor: Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
}

struct StatusBarView: View {
    let lastResult: Int?
    let top4Accuracy: String
    let outcome: PredictionOutcome

    var body: some View {
        HStack(spacing: 20) {
            if let result = lastResult {
                Text("Последний результат: \(result)")
                    .font(.subheadline)
            }

            Text("Точность TOP-4: \(top4Accuracy)")
                .font(.subheadline)

            Text("Прогноз: \(outcomeSymbol)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(outcomeColor)
        }
    }

    private var outcomeSymbol: String {
        switch outcome {
        case .success: return "✓"
        case .miss: return "✗"
        case .pending: return "—"
        }
    }

    private var outcomeColor: Color {
        switch outcome {
        case .success: return .green
        case .miss: return .red
        case .pending: return .secondary
        }
    }
}

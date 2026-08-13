import SwiftUI

struct AIStatusPanel: View {
    let sceneState: GameSceneState
    let insight: AIActionInsight
    let detectedNumbers: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ИИ-анализ экрана", systemImage: "brain.head.profile")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                Label(sceneState.rawValue, systemImage: sceneState.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if insight.playerDetected {
                    Label("Игрок виден", systemImage: "person.fill.checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Text(insight.aiDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if !detectedNumbers.isEmpty {
                Text("Числа на экране: \(detectedNumbers.map(String.init).joined(separator: ", "))")
                    .font(.caption.monospacedDigit())
            }

            ProgressView(value: insight.throwPhaseProgress) {
                Text("Фаза броска")
                    .font(.caption2)
            }
            .tint(.orange)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

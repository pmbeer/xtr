import SwiftUI

struct PredictionDisplayView: View {
    let predictions: [TopPrediction]
    let confidence: ConfidenceLevel
    let confidenceScore: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("СЛЕДУЮЩИЙ ПРОГНОЗ")
                .font(.headline)
                .foregroundStyle(.secondary)

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

import SwiftUI
import AppKit

struct LivePreviewPanel: View {
    let image: CGImage?
    let cropSize: CGSize
    let captureFrames: Int
    var captureBackend: String = "—"
    var windowTitle: String?
    var zones: GameWindowZones = .fonBetDefault
    var isAnalyzing: Bool = false
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Окно игры (live)", systemImage: "macwindow")
                    .font(.caption.weight(.semibold))
                if isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Text("\(captureBackend) · \(captureFrames) fps · \(Int(cropSize.width))×\(Int(cropSize.height))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let windowTitle {
                Text(windowTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let img = image {
                Image(decorative: img, scale: 1.0)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        ZoneOverlayView(zones: zones)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.4), lineWidth: 1))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 100)
                    .overlay {
                        Text("Нет кадра — выберите окно Safari с fon.bet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }

            HStack(spacing: 8) {
                zoneLegend(color: .red, label: "Результаты")
                zoneLegend(color: .green, label: "Игрок")
                zoneLegend(color: .blue, label: "Доска")
            }
            .font(.caption2)

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

    private func zoneLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.7))
                .frame(width: 10, height: 10)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

struct ZoneOverlayView: View {
    let zones: GameWindowZones

    var body: some View {
        GeometryReader { geo in
            zoneBox(zones.dartboardZone, color: .blue, in: geo.size)
            zoneBox(zones.playerZone, color: .green, in: geo.size)
            zoneBox(zones.resultsZone, color: .red, in: geo.size)
        }
        .allowsHitTesting(false)
    }

    private func zoneBox(_ zone: NormalizedRect, color: Color, in size: CGSize) -> some View {
        let rect = zone.cgRect(for: size)
        return Rectangle()
            .strokeBorder(color.opacity(0.85), lineWidth: 2)
            .background(color.opacity(0.08))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

struct AIStatusPanel: View {
    let phase: GamePhase
    let sceneState: GameSceneState
    let insight: AIActionInsight
    let resultHistory: [Int]
    let bettingSeconds: Double?
    let throwInProgress: Bool
    let dartboardMotion: Double
    let playerMotion: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ИИ-анализ (online)", systemImage: "brain.head.profile")
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
                .lineLimit(3)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("🔴 История бросков:")
                        .font(.caption2.weight(.semibold))
                    Text(resultHistory.isEmpty ? "—" : resultHistory.map(String.init).joined(separator: " → "))
                        .font(.caption.monospacedDigit())
                }
                HStack {
                    Text("🟢 Игрок:")
                        .font(.caption2.weight(.semibold))
                    Text("\(insight.detectedAction.rawValue) · движение \(Int(playerMotion * 100))%")
                        .font(.caption2)
                }
                HStack {
                    Text("🔵 Доска:")
                        .font(.caption2.weight(.semibold))
                    Text(motionLabel(dartboardMotion))
                        .font(.caption2)
                }
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

    private var phaseColor: Color {
        switch phase {
        case .bettingWindow: return .blue
        case .throwing: return .orange
        case .resultShown: return .green
        default: return .secondary
        }
    }

    private func motionLabel(_ motion: Double) -> String {
        if motion > 0.18 { return "бросок! \(Int(motion * 100))%" }
        if motion > 0.08 { return "движение \(Int(motion * 100))%" }
        return "стабильна \(Int(motion * 100))%"
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

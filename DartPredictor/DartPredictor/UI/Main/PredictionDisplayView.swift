import SwiftUI
import AppKit

struct LivePreviewPanel: View {
    let image: CGImage?
    let cropSize: CGSize
    let captureFrames: Int
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Область игры (live)", systemImage: "rectangle.dashed.badge.record")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(captureFrames) кадров · \(Int(cropSize.width))×\(Int(cropSize.height))")
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

import SwiftUI

struct MainDashboardView: View {
    @ObservedObject var pipeline = PipelineCoordinator.shared
    @ObservedObject var accuracy = AccuracyManager.shared
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        VStack(spacing: 16) {
            AIStatusPanel(
                sceneState: pipeline.sceneState,
                insight: pipeline.aiInsight,
                detectedNumbers: pipeline.detectedNumbersOnScreen
            )

            PredictionDisplayView(
                predictions: pipeline.currentPrediction.predictions,
                combination: pipeline.currentCombination,
                confidence: pipeline.currentPrediction.confidence,
                confidenceScore: pipeline.currentPrediction.confidenceScore
            )

            Divider()

            StatusBarView(
                lastResult: pipeline.lastResult,
                top4Accuracy: accuracy.formattedTop4(),
                outcome: pipeline.lastOutcome
            )

            HStack {
                Label(pipeline.processingState, systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer()

                if pipeline.lastCropSize.width > 0 {
                    Text("\(Int(pipeline.lastCropSize.width))×\(Int(pipeline.lastCropSize.height))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if settings.settings.isPaperPredictionMode {
                    Text("Paper Prediction")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }

                Text("Таймер: \(String(format: "%.1f", pipeline.decisionTimerRemaining)) сек")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(pipeline.isRunning ? "Остановить" : "Запустить") {
                    Task {
                        if pipeline.isRunning {
                            await pipeline.stop()
                        } else {
                            await pipeline.start()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Выбрать экран") {
                    NotificationCenter.default.post(name: .showRegionSetup, object: nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

extension Notification.Name {
    static let showRegionSetup = Notification.Name("showRegionSetup")
}

import SwiftUI

struct MainDashboardView: View {
    @ObservedObject var pipeline = PipelineCoordinator.shared
    @ObservedObject var accuracy = AccuracyManager.shared
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        VStack(spacing: 14) {
            if pipeline.needsScreenPermission {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Разрешите «Запись экрана» для DartPredictor")
                        .font(.caption)
                    Spacer()
                    Button("Открыть настройки") {
                        pipeline.requestPermission()
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            LivePreviewPanel(
                image: pipeline.livePreviewImage,
                cropSize: pipeline.lastCropSize,
                captureFrames: pipeline.captureFrames,
                captureBackend: pipeline.captureBackend.rawValue,
                error: pipeline.captureError
            )

            AIStatusPanel(
                phase: pipeline.gamePhase,
                sceneState: pipeline.sceneState,
                insight: pipeline.aiInsight,
                detectedNumbers: pipeline.detectedNumbersOnScreen,
                bettingSeconds: pipeline.bettingSecondsOnScreen,
                throwInProgress: pipeline.throwInProgress
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

            Text(pipeline.processingState)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button(pipeline.isRunning ? "Остановить" : "Запустить") {
                    Task {
                        if pipeline.isRunning {
                            pipeline.stop()
                        } else {
                            await pipeline.start()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Выбрать область игры") {
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

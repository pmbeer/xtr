import SwiftUI

struct MainDashboardView: View {
    @ObservedObject var pipeline = PipelineCoordinator.shared
    @ObservedObject var accuracy = AccuracyManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @Binding var showWindowPicker: Bool

    @State private var isCalibratingZones = false
    @State private var editingZones = GameWindowZones.fonBetDefault
    @State private var selectedZoneKind: EditableZoneKind = .results

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

            if settings.selectedCaptureWindow == nil {
                HStack {
                    Image(systemName: "macwindow.badge.plus")
                        .foregroundStyle(.blue)
                    Text("Выберите окно Safari с fon.bet — ИИ будет смотреть это окно")
                        .font(.caption)
                    Spacer()
                    Button("Выбрать окно") { showWindowPicker = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(8)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            LivePreviewPanel(
                image: pipeline.livePreviewImage,
                cropSize: pipeline.lastCropSize,
                captureFrames: pipeline.captureFrames,
                captureBackend: pipeline.captureBackend.rawValue,
                windowTitle: settings.selectedCaptureWindow?.shortLabel,
                zones: isCalibratingZones ? $editingZones : Binding(
                    get: { settings.settings.gameWindowZones },
                    set: { _ in }
                ),
                isCalibrating: isCalibratingZones,
                selectedZoneKind: selectedZoneKind,
                isAnalyzing: pipeline.isLiveAnalyzing,
                error: pipeline.captureError
            )

            if isCalibratingZones {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Зона", selection: $selectedZoneKind) {
                        ForEach(EditableZoneKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Button("Сохранить зоны") {
                            settings.setGameWindowZones(editingZones)
                            pipeline.onZonesUpdated()
                            isCalibratingZones = false
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Сбросить по умолчанию") {
                            editingZones = .fonBetDefault
                        }
                        .buttonStyle(.bordered)

                        Button("Отмена") {
                            editingZones = settings.settings.gameWindowZones
                            isCalibratingZones = false
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(8)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            AIStatusPanel(
                phase: pipeline.gamePhase,
                sceneState: pipeline.sceneState,
                insight: pipeline.aiInsight,
                resultHistory: pipeline.resultHistoryNumbers,
                bettingSeconds: pipeline.bettingSecondsOnScreen,
                throwInProgress: pipeline.throwInProgress,
                dartboardMotion: pipeline.dartboardMotion,
                playerMotion: pipeline.playerZoneMotion
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
                .lineLimit(4)
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
                .disabled(settings.selectedCaptureWindow == nil)

                Button("Выбрать окно") {
                    showWindowPicker = true
                }
                .buttonStyle(.bordered)

                Button(isCalibratingZones ? "Калибровка…" : "Калибровка зон") {
                    if isCalibratingZones {
                        editingZones = settings.settings.gameWindowZones
                        isCalibratingZones = false
                    } else {
                        editingZones = settings.settings.gameWindowZones
                        selectedZoneKind = .results
                        isCalibratingZones = true
                        if pipeline.livePreviewImage == nil {
                            Task { await pipeline.testCapturePreview() }
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(settings.selectedCaptureWindow == nil)
            }
        }
        .padding()
    }
}

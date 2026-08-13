import SwiftUI

public struct TrainingView: View {
    @ObservedObject var pipeline: PipelineCoordinator

    var body: some View {
        let acc = pipeline.learning.accuracy.snapshot
        let weights = pipeline.learning.currentWeights()

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Обучение")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                groupBox("Фаза") {
                    Text(pipeline.learning.phase.rawValue)
                        .font(.title3.bold())
                        .foregroundStyle(.teal)
                    Text(pipeline.learning.lastMessage)
                        .foregroundStyle(.white.opacity(0.7))
                }

                groupBox("Статистика") {
                    stat("Обучающих примеров", "\(pipeline.learning.trainingSamples)")
                    stat("Всего прогнозов", "\(acc.totalPredictions)")
                    stat("Успешных (TOP-4)", "\(acc.successes)")
                    stat("Ошибок", "\(acc.misses)")
                    stat("TOP-1", pct(acc.top1Accuracy))
                    stat("TOP-2", pct(acc.top2Accuracy))
                    stat("TOP-4", pct(acc.top4Accuracy))
                    stat("Последние 10", pct(acc.windowAccuracy(acc.recent10)))
                    stat("Последние 50", pct(acc.windowAccuracy(acc.recent50)))
                    stat("Последние 100", pct(acc.windowAccuracy(acc.recent100)))
                    stat("Общая точность", pct(acc.overallAccuracy))
                }

                groupBox("Веса моделей") {
                    ForEach(ModelKind.allCases) { kind in
                        let w = weights[kind.rawValue] ?? kind.defaultWeight
                        HStack {
                            Text(kind.displayName)
                                .foregroundStyle(.white)
                            Spacer()
                            ProgressView(value: w)
                                .frame(width: 160)
                            Text(String(format: "%.1f%%", w * 100))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.teal)
                                .frame(width: 56, alignment: .trailing)
                        }
                    }
                }

                groupBox("Профиль игрока") {
                    Text(pipeline.learning.profiles.activeProfile.displayName)
                        .foregroundStyle(.white)
                    Text("Бросков в профиле: \(pipeline.learning.profiles.activeProfile.throwCount)")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private func groupBox(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func stat(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text(value).foregroundStyle(.white).font(.body.monospacedDigit())
        }
    }

    private func pct(_ v: Double) -> String {
        String(format: "%.1f%%", v * 100)
    }
}

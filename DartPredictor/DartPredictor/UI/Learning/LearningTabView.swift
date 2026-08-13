import SwiftUI

struct LearningTabView: View {
    @ObservedObject var learning = LearningEngine.shared
    @ObservedObject var accuracy = AccuracyManager.shared
    @ObservedObject var profileManager = PlayerProfileManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Фаза обучения") {
                    Text(learning.currentPhase.rawValue)
                        .font(.title2.weight(.bold))
                }

                GroupBox("Статистика") {
                    VStack(alignment: .leading, spacing: 8) {
                        statRow("Обучающих примеров", "\(accuracy.stats.totalPredictions)")
                        statRow("TOP-1 точность", accuracy.formattedTop1())
                        statRow("TOP-4 точность", accuracy.formattedTop4())
                        statRow("Успешных прогнозов", "\(accuracy.stats.successfulPredictions)")
                        statRow("Ошибок", "\(accuracy.stats.failedPredictions)")
                        statRow("Последние 10", accuracy.formattedRecent(10))
                        statRow("Последние 50", accuracy.formattedRecent(50))
                        statRow("Последние 100", accuracy.formattedRecent(100))
                        statRow("Общая точность", accuracy.formattedOverall())
                    }
                }

                GroupBox("Веса моделей") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(PredictionModelType.allCases) { type in
                            let weight = learning.modelWeights[type] ?? 0
                            HStack {
                                Text(type.displayName)
                                Spacer()
                                Text(String(format: "%.1f%%", weight * 100))
                                    .monospacedDigit()
                            }
                            ProgressView(value: weight)
                                .tint(.blue)
                        }
                    }
                }

                GroupBox("Профиль игрока") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profileManager.activeProfile.name)
                            .font(.headline)
                        Text("Бросков: \(profileManager.activeProfile.throwHistory.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            profileManager.load()
            accuracy.update(from: profileManager.activeProfile)
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .monospacedDigit()
                .fontWeight(.medium)
        }
    }
}

import SwiftUI

struct HistoryTabView: View {
    @ObservedObject var history = HistoryManager.shared

    var body: some View {
        Table(history.displayEntries) {
            TableColumn("№") { entry in
                Text("\(historyIndex(entry))")
                    .monospacedDigit()
            }
            .width(50)

            TableColumn("Фактическое") { entry in
                Text("\(entry.actualResult ?? entry.currentResult)")
                    .fontWeight(.semibold)
            }
            .width(90)

            TableColumn("Прогноз 1") { entry in
                Text(entry.predictedNumbers.indices.contains(0) ? "\(entry.predictedNumbers[0])" : "—")
            }
            .width(70)

            TableColumn("Прогноз 2") { entry in
                Text(entry.predictedNumbers.indices.contains(1) ? "\(entry.predictedNumbers[1])" : "—")
            }
            .width(70)

            TableColumn("Прогноз 3") { entry in
                Text(entry.predictedNumbers.indices.contains(2) ? "\(entry.predictedNumbers[2])" : "—")
            }
            .width(70)

            TableColumn("Прогноз 4") { entry in
                Text(entry.predictedNumbers.indices.contains(3) ? "\(entry.predictedNumbers[3])" : "—")
            }
            .width(70)

            TableColumn("Результат") { entry in
                Text(resultSymbol(entry))
                    .foregroundStyle(resultColor(entry))
                    .fontWeight(.semibold)
            }
            .width(60)
        }
        .onAppear { history.load() }
    }

    private func historyIndex(_ entry: PredictionEntry) -> Int {
        let sorted = history.entries.sorted { $0.timestamp < $1.timestamp }
        return (sorted.firstIndex(where: { $0.id == entry.id }) ?? 0) + 1
    }

    private func resultSymbol(_ entry: PredictionEntry) -> String {
        switch entry.predictionOutcome {
        case .success: return "✓"
        case .miss: return "✗"
        case .pending: return "—"
        }
    }

    private func resultColor(_ entry: PredictionEntry) -> Color {
        switch entry.predictionOutcome {
        case .success: return .green
        case .miss: return .red
        case .pending: return .secondary
        }
    }
}

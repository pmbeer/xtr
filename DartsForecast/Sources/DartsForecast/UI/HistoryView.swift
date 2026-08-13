import SwiftUI

public struct HistoryView: View {
    let records: [ThrowRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("История")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Table(records.reversed()) {
                TableColumn("№") { r in Text("\(r.index)") }
                TableColumn("Фактическое") { r in
                    Text(r.actualResult.map(String.init) ?? "—")
                }
                TableColumn("Прогноз 1") { r in Text(num(r, 0)) }
                TableColumn("Прогноз 2") { r in Text(num(r, 1)) }
                TableColumn("Прогноз 3") { r in Text(num(r, 2)) }
                TableColumn("Прогноз 4") { r in Text(num(r, 3)) }
                TableColumn("Результат") { r in
                    Text(resultMark(r))
                        .foregroundStyle(r.predictionCorrect == true ? .green : (r.predictionCorrect == false ? .red : .secondary))
                }
            }
            .frame(minHeight: 360)
        }
    }

    private func num(_ r: ThrowRecord, _ i: Int) -> String {
        guard r.predictedNumbers.indices.contains(i) else { return "—" }
        return "\(r.predictedNumbers[i])"
    }

    private func resultMark(_ r: ThrowRecord) -> String {
        switch r.predictionCorrect {
        case true: return "✓"
        case false: return "✗"
        default: return "…"
        }
    }
}

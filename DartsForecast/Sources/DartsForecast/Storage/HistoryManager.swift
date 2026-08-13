import Foundation
import Combine

@MainActor
final class HistoryManager: ObservableObject {
    @Published private(set) var records: [ThrowRecord] = []
    @Published private(set) var sequence: [Int] = []

    func load(records: [ThrowRecord], sequence: [Int]) {
        self.records = records
        self.sequence = sequence
    }

    func appendResult(_ value: Int) {
        sequence.append(value)
        if sequence.count > HardwareProfile.maxHistoryInMemory {
            sequence.removeFirst(sequence.count - HardwareProfile.maxHistoryInMemory)
        }
    }

    func addRecord(_ record: ThrowRecord) {
        records.append(record)
        if records.count > HardwareProfile.maxHistoryInMemory {
            records.removeFirst(records.count - HardwareProfile.maxHistoryInMemory)
        }
    }

    /// Закрывает предыдущий pending-record фактическим результатом.
    func closePending(with actual: Int) -> ThrowRecord? {
        guard var last = records.last, last.actualResult == nil else { return nil }
        last.actualResult = actual
        last.predictionCorrect = last.predictedNumbers.contains(actual)
        records[records.count - 1] = last
        return last
    }
}

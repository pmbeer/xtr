import Foundation

enum ThrowDetection: Equatable {
    case none
    case seed([Int])
    case newThrow(Int)
}

struct ThrowDetector {
    var newestFirst = true
    var requiredStableFrames = 2

    private var pendingValues: [Int] = []
    private var stableFrameCount = 0
    private var acceptedValues: [Int]?

    mutating func ingest(_ values: [Int]) -> ThrowDetection {
        let cleanValues = Array(values.filter { (1...20).contains($0) }.prefix(24))
        guard !cleanValues.isEmpty else {
            pendingValues = []
            stableFrameCount = 0
            return .none
        }

        if cleanValues == pendingValues {
            stableFrameCount += 1
        } else {
            pendingValues = cleanValues
            stableFrameCount = 1
        }

        guard stableFrameCount >= requiredStableFrames else { return .none }
        guard let previous = acceptedValues else {
            acceptedValues = cleanValues
            return .seed(cleanValues)
        }
        guard previous != cleanValues else { return .none }

        acceptedValues = cleanValues
        guard let value = inferNewValue(previous: previous, current: cleanValues) else {
            return .none
        }
        return .newThrow(value)
    }

    mutating func reset() {
        pendingValues = []
        stableFrameCount = 0
        acceptedValues = nil
    }

    private func inferNewValue(previous: [Int], current: [Int]) -> Int? {
        if newestFirst {
            if current.count == previous.count,
               Array(current.dropFirst()) == Array(previous.dropLast()) {
                return current.first
            }
            return current.first != previous.first ? current.first : nil
        }

        if current.count == previous.count,
           Array(current.dropLast()) == Array(previous.dropFirst()) {
            return current.last
        }
        return current.last != previous.last ? current.last : nil
    }
}

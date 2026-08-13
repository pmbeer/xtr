import Foundation
import Accelerate

/// Лёгкая нейросеть для классификации действий и прогноза числа.
/// Работает на CPU через Accelerate — подходит для Intel Mac 8 GB RAM.
final class NeuralActionClassifier {
    static let shared = NeuralActionClassifier()

    private let inputSize = 55  // 5 кадров × 11 признаков
    private let hiddenSize = 32
    private let outputSize = 20 // числа 1–20

    private var weightsIH: [Double] = []
    private var weightsHO: [Double] = []
    private var biasH: [Double] = []
    private var biasO: [Double] = []

    private let storageKey = "neural_action_classifier"

    init() {
        loadOrInitialize()
    }

    func predictNumber(from featureSequence: [Double]) -> [Int: Double] {
        let input = padInput(featureSequence)
        let hidden = forwardHidden(input)
        let output = forwardOutput(hidden)
        return mapOutputToNumbers(output)
    }

    func train(actual: Int, featureSequence: [Double], learningRate: Double = 0.02) {
        guard DartConstants.validNumbers.contains(actual) else { return }
        let input = padInput(featureSequence)
        let hidden = forwardHidden(input)
        let output = forwardOutput(hidden)

        let targetIndex = actual - 1
        var errorO = output
        for i in 0..<outputSize {
            errorO[i] = output[i] - (i == targetIndex ? 1.0 : 0.0)
        }

        var hiddenError = [Double](repeating: 0, count: hiddenSize)
        for h in 0..<hiddenSize {
            var sum = 0.0
            for o in 0..<outputSize {
                sum += errorO[o] * weightsHO[h * outputSize + o]
            }
            hiddenError[h] = sum * reluDerivative(hidden[h])
        }

        for h in 0..<hiddenSize {
            for o in 0..<outputSize {
                weightsHO[h * outputSize + o] -= learningRate * errorO[o] * hidden[h]
            }
        }
        for o in 0..<outputSize {
            biasO[o] -= learningRate * errorO[o]
        }

        for i in 0..<inputSize {
            for h in 0..<hiddenSize {
                weightsIH[i * hiddenSize + h] -= learningRate * hiddenError[h] * input[i]
            }
        }
        for h in 0..<hiddenSize {
            biasH[h] -= learningRate * hiddenError[h]
        }

        save()
    }

    private func padInput(_ features: [Double]) -> [Double] {
        if features.count >= inputSize {
            return Array(features.suffix(inputSize))
        }
        return Array(repeating: 0, count: inputSize - features.count) + features
    }

    private func forwardHidden(_ input: [Double]) -> [Double] {
        var hidden = [Double](repeating: 0, count: hiddenSize)
        for h in 0..<hiddenSize {
            var sum = biasH[h]
            for i in 0..<inputSize {
                sum += input[i] * weightsIH[i * hiddenSize + h]
            }
            hidden[h] = relu(sum)
        }
        return hidden
    }

    private func forwardOutput(_ hidden: [Double]) -> [Double] {
        var output = [Double](repeating: 0, count: outputSize)
        for o in 0..<outputSize {
            var sum = biasO[o]
            for h in 0..<hiddenSize {
                sum += hidden[h] * weightsHO[h * outputSize + o]
            }
            output[o] = sum
        }
        return softmax(output)
    }

    private func mapOutputToNumbers(_ output: [Double]) -> [Int: Double] {
        var scores: [Int: Double] = [:]
        for i in 0..<outputSize {
            scores[i + 1] = output[i]
        }
        return scores
    }

    private func relu(_ x: Double) -> Double { max(0, x) }
    private func reluDerivative(_ x: Double) -> Double { x > 0 ? 1 : 0 }

    private func softmax(_ values: [Double]) -> [Double] {
        let maxVal = values.max() ?? 0
        let exps = values.map { exp($0 - maxVal) }
        let sum = exps.reduce(0, +)
        guard sum > 0 else { return values }
        return exps.map { $0 / sum }
    }

    private func loadOrInitialize() {
        let url = storageURL()
        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode(NeuralWeights.self, from: data) {
            weightsIH = saved.weightsIH
            weightsHO = saved.weightsHO
            biasH = saved.biasH
            biasO = saved.biasO
            return
        }
        initializeRandom()
    }

    private func initializeRandom() {
        weightsIH = (0..<inputSize * hiddenSize).map { _ in Double.random(in: -0.1...0.1) }
        weightsHO = (0..<hiddenSize * outputSize).map { _ in Double.random(in: -0.1...0.1) }
        biasH = [Double](repeating: 0, count: hiddenSize)
        biasO = [Double](repeating: 0, count: outputSize)
    }

    private func save() {
        let weights = NeuralWeights(weightsIH: weightsIH, weightsHO: weightsHO, biasH: biasH, biasO: biasO)
        if let data = try? JSONEncoder().encode(weights) {
            try? data.write(to: storageURL(), options: .atomic)
        }
    }

    private func storageURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DartPredictor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(storageKey + ".json")
    }

    private struct NeuralWeights: Codable {
        let weightsIH: [Double]
        let weightsHO: [Double]
        let biasH: [Double]
        let biasO: [Double]
    }
}

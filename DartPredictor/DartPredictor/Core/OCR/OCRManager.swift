import Foundation
import Vision
import CoreGraphics

final class OCRManager {
    static let shared = OCRManager()

    private let processingQueue = DispatchQueue(label: "com.dartpredictor.ocr", qos: .userInteractive)
    private var lastRecognizedText: String = ""
    private var pendingNumber: Int?
    private var confirmationCount = 0
    private let requiredConfirmations = DartConstants.ocrDebounceFrames

    func recognizeNumber(from image: CGImage, completion: @escaping (Int?) -> Void) {
        processingQueue.async { [weak self] in
            guard let self else { return }
            let number = self.performOCR(on: image)
            DispatchQueue.main.async {
                completion(number)
            }
        }
    }

    private func performOCR(on image: CGImage) -> Int? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0.02

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            DebugLogger.shared.logOCRError(error.localizedDescription)
            return nil
        }

        guard let observations = request.results else { return nil }

        let candidates = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .flatMap { extractNumbers(from: $0) }

        return candidates.first
    }

    private func extractNumbers(from text: String) -> [Int] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"\b(\d{1,2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(cleaned.startIndex..., in: cleaned)
        let matches = regex.matches(in: cleaned, range: range)

        return matches.compactMap { match -> Int? in
            guard let r = Range(match.range(at: 1), in: cleaned) else { return nil }
            let value = Int(cleaned[r])
            guard let value, DartConstants.validNumbers.contains(value) else { return nil }
            return value
        }
    }

    /// Debounced confirmation: returns confirmed number only after stable readings
    func processWithDebounce(recognized: Int?, rawText: String = "") -> Int? {
        guard let number = recognized else {
            confirmationCount = 0
            pendingNumber = nil
            return nil
        }

        if number == pendingNumber {
            confirmationCount += 1
        } else {
            pendingNumber = number
            confirmationCount = 1
        }

        guard confirmationCount >= requiredConfirmations else { return nil }

        if let last = Int(lastRecognizedText), last == number {
            return nil
        }

        lastRecognizedText = String(number)
        confirmationCount = 0
        pendingNumber = nil
        return number
    }

    func reset() {
        lastRecognizedText = ""
        pendingNumber = nil
        confirmationCount = 0
    }
}

import CoreGraphics
import Vision

/// Распознавание числа (счёта игрока) в маленьком фрагменте экрана
/// через встроенный Apple Vision — быстро и без внешних зависимостей.
enum DigitOCR {
    static func readNumber(from image: CGImage) -> Int? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined()
        let digits = text.filter { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, digits.count <= 5, let value = Int(digits) else {
            return nil
        }
        return value
    }
}

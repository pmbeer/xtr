import Foundation
import os.log

final class DebugLogger {
    static let shared = DebugLogger()

    private let logger = Logger(subsystem: "com.dartpredictor.app", category: "pipeline")
    private let queue = DispatchQueue(label: "com.dartpredictor.debuglog", qos: .utility)
    private var logFileURL: URL?
    private var isEnabled = false

    func configure(enabled: Bool) {
        isEnabled = enabled
        if enabled {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("DartPredictor/logs", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            logFileURL = dir.appendingPathComponent("debug.log")
        }
    }

    func log(_ message: String, category: String = "general") {
        guard isEnabled else { return }
        let entry = "[\(ISO8601DateFormatter().string(from: Date()))] [\(category)] \(message)"
        logger.debug("\(entry)")
        queue.async { [weak self] in
            guard let url = self?.logFileURL else { return }
            if let data = (entry + "\n").data(using: .utf8) {
                if FileManager.default.fileExists(atPath: url.path) {
                    if let handle = try? FileHandle(forWritingTo: url) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        try? handle.close()
                    }
                } else {
                    try? data.write(to: url)
                }
            }
        }
    }

    func logThrowDetected(number: Int, timeMs: Double) {
        log("Throw detected: \(number), detection time: \(String(format: "%.1f", timeMs))ms", category: "throw")
    }

    func logPrediction(numbers: [Int], probabilities: [Double], timeMs: Double) {
        let formatted = numbers.enumerated().map { i, n in
            let p = i < probabilities.count ? probabilities[i] : 0
            return "\(n)=\(String(format: "%.1f", p))%"
        }.joined(separator: ", ")
        log("Prediction: \(formatted), processing: \(String(format: "%.1f", timeMs))ms", category: "prediction")
    }

    func logWeightUpdate(weights: [String: Double]) {
        let formatted = weights.map { "\($0.key): \(String(format: "%.2f", $0.value))" }.joined(separator: ", ")
        log("Weight update: \(formatted)", category: "learning")
    }

    func logOCRError(_ error: String) {
        log("OCR error: \(error)", category: "ocr")
    }

    func logCaptureError(_ error: String) {
        log("Capture error: \(error)", category: "capture")
    }

    func logVisionError(_ error: String) {
        log("Vision error: \(error)", category: "vision")
    }
}

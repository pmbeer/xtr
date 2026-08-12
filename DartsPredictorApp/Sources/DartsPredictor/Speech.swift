import AVFoundation

/// Голосовые подсказки через системный синтезатор речи.
final class Speech {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        utterance.rate = 0.55
        synthesizer.speak(utterance)
    }
}

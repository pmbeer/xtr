import Foundation

/// Состояние пайплайна анализа: бросок → поведение → обучение → прогноз.
enum AnalysisPipelineStep: String, CaseIterable {
    case idle
    case watchingOutcome      // читаем исход броска (СЕРИЯ)
    case analyzingBehavior    // анализ игрока
    case evaluatingPrediction // проверка прошлого прогноза
    case learning             // обучение модели
    case generatingForecast   // новый прогноз

    var displayName: String {
        switch self {
        case .idle: return "Ожидание"
        case .watchingOutcome: return "Исход броска"
        case .analyzingBehavior: return "Поведение игрока"
        case .evaluatingPrediction: return "Проверка прогноза"
        case .learning: return "Обучение"
        case .generatingForecast: return "Прогноз ставки"
        }
    }

    var icon: String {
        switch self {
        case .idle: return "pause.circle"
        case .watchingOutcome: return "number.circle"
        case .analyzingBehavior: return "figure.stand"
        case .evaluatingPrediction: return "checkmark.circle"
        case .learning: return "brain"
        case .generatingForecast: return "target"
        }
    }
}

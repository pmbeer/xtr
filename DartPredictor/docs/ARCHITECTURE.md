# Архитектура DartPredictor

## Обзор

DartPredictor — нативное macOS-приложение для анализа результатов дартса и прогнозирования следующего числа. Pipeline работает в реальном времени с целевым временем обработки до 3 секунд.

```
Screen Capture → OCR → Throw Detection → Player Vision → Feature Extraction
    → Prediction → TOP-4 → Result Verification → Online Learning → Weight Update → Storage
```

## Модули

| Модуль | Файл | Ответственность |
|--------|------|-----------------|
| ScreenCaptureManager | Core/Capture/ | Захват экрана через ScreenCaptureKit |
| OCRManager | Core/OCR/ | Vision OCR, debounce, фильтрация |
| ThrowDetector | Core/Detection/ | Подтверждение нового броска |
| PlayerVisionAnalyzer | Core/Vision/ | Анализ позы и движения игрока |
| SequenceModel | Core/Models/ | Паттерны последовательностей (A) |
| FrequencyModel | Core/Models/ | Частотность чисел (B) |
| TransitionModel | Core/Models/ | Таблица переходов (C) |
| PlayerBehaviorModel | Core/Models/ | Корреляция поведения (D) |
| TimingModel | Core/Models/ | Временные паттерны (E) |
| EnsemblePredictor | Core/Learning/ | Ансамбль моделей (F) |
| LearningEngine | Core/Learning/ | Обучение и обновление весов |
| AccuracyManager | Core/Accuracy/ | Статистика точности |
| PlayerProfileManager | Core/Learning/ | Профили игроков |
| HistoryManager | Core/Storage/ | История прогнозов |
| PredictionStore | Core/Storage/ | Персистентное хранение |
| SettingsManager | Core/Storage/ | Настройки приложения |
| PipelineCoordinator | Core/Pipeline/ | Оркестрация pipeline |
| RegionSelector | UI/RegionSelector/ | Безопасный выбор областей |
| PredictionOverlay | UI/Overlay/ | Плавающее окно |

## Pipeline

### 1. Захват экрана (0–300 мс)

`ScreenCaptureManager` использует ScreenCaptureKit для захвата двух областей:

- **result** — для OCR
- **player** — для анализа поведения

Кадры обрабатываются на `captureQueue` (userInteractive QoS). OCR запускается с пропуском кадров.

### 2. OCR и подтверждение броска

`OCRManager` выполняет Vision OCR только на области результатов:

- Фильтрация: только числа 1–20
- Debounce: 3 последовательных совпадения
- Исключение повторного распознавания

`ThrowDetector` подтверждает новый бросок с минимальным интервалом 2 сек.

### 3. Анализ игрока

`PlayerVisionAnalyzer`:

- Уменьшает изображение до 35% (оптимизация для 8 GB RAM)
- Motion detection между кадрами
- VNDetectHumanBodyPose для позы
- Извлечение: наклон, плечи, рука, замах, скорость, ритм

### 4. Прогнозирование

`EnsemblePredictor` объединяет 5 моделей с адаптивными весами:

```
final_score[n] = Σ (model_score[n] × model_weight)
```

TOP-4 выбираются по максимальному score, проценты нормализуются до 100%.

### 5. Обучение

После каждого броска `LearningEngine`:

1. Сравнивает предыдущий TOP-4 с фактическим результатом
2. Обновляет каждую модель инкрементально
3. Корректирует веса с сглаживанием (α = 0.08)
4. Обновляет фазу обучения

Фазы: СБОР ДАННЫХ (0–30) → КАЛИБРАВКА (30–100) → АДАПТИВНОЕ ОБУЧЕНИЕ (100–300) → СТАБИЛЬНАЯ МОДЕЛЬ (300+).

### 6. Персистентность

Данные в `~/Library/Application Support/DartPredictor/`:

| Файл | Содержимое |
|------|------------|
| predictions.json | История прогнозов (до 10000 записей) |
| profiles.json | Профили игроков и веса моделей |
| settings.json | Настройки и области экрана |
| logs/debug.log | Debug лог (опционально) |

## UI

- **Прогноз** — главный dashboard с TOP-4
- **История** — таблица прогнозов
- **Обучение** — веса, точность, фаза
- **Настройки** — области, Paper Prediction, overlay
- **Overlay** — NSPanel с TOP-4 поверх других приложений

## Region Selector (безопасность)

Предыдущая версия падала с EXC_BAD_ACCESS при выборе области. Новая реализация:

- Отдельный `NSWindowController` с сильными ссылками
- `weak self` в callbacks
- Явная очистка при закрытии (`contentView = nil`)
- Флаг `isClosed` для предотвращения двойного вызова
- Координаты конвертируются в screen space

## Оптимизация для MacBook Pro 2018

1. Уменьшенное разрешение для анализа игрока (35%)
2. Пропуск кадров OCR (каждый 3-й кадр)
3. Capture FPS = 15, OCR FPS ≈ 5
4. Инкрементальное обучение без batch retraining
5. Лёгкие модели без GPU/Core ML
6. Background queues для всех тяжёлых операций
7. `@MainActor` только для UI обновлений

## Тестирование

Unit-тесты в `DartPredictorTests/`:

- Нормализация моделей
- Ensemble TOP-4
- OCR debounce
- Accuracy stats

Запуск: Product → Test (⌘U) в Xcode.

## Безопасность

- **Нет автоматических ставок** — только чтение экрана и отображение
- **Paper Prediction** — режим без действий на сайте
- **Честная статистика** — без искусственного завышения процентов
- **Локальное хранение** — данные не отправляются в сеть

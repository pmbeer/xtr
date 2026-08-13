# Архитектура Darts Forecast

## Pipeline

```
Screen Capture (result ROI + player ROI)
        │
        ├─► OCRManager ─► ThrowDetector (debounce/confirm)
        │                        │
        │                        ▼
        │              LearningEngine.onNewResult
        │                        │
        └─► PlayerVisionAnalyzer ┘
                                 │
                    EnsemblePredictor (A–F)
                                 │
                         TOP-4 + probs=100%
                                 │
                    UI + Floating Overlay
                                 │
                         PredictionStore
```

Цикл после броска:

1. Подтвердить новый результат (несколько стабильных кадров OCR)
2. Проверить прошлый ТОП-4 (SUCCESS/MISS)
3. Обучить модели A–E инкрементально
4. Сглаженно обновить веса ансамбля F
5. Сохранить state.json
6. Сформировать новый ТОП-4
7. Показать пользователю (< 3 с целевой бюджет)

## Модули

| Модуль | Назначение |
|--------|------------|
| ScreenCaptureManager | CGDisplay crop, низкий FPS, downscale игрока |
| OCRManager | Vision OCR fast, только ROI результата |
| ThrowDetector | Фильтр OCR, confirmation N кадров, anti-duplicate |
| PlayerVisionAnalyzer | Pose + motion energy по последовательности кадров |
| SequenceModel | n-граммы окон 3/5/10/20/50 |
| FrequencyModel | hot/cold, recency, conditional |
| TransitionModel | Markov 1–2 |
| PlayerBehaviorModel | behaviorKey → outcome |
| TimingModel | интервалы / подготовка / ритм |
| EnsemblePredictor | взвешенное смешивание + нормализация TOP-4 |
| LearningEngine | verify → learn → predict |
| AccuracyManager | TOP-1/2/4, окна 10/50/100 |
| PlayerProfileManager | профили + Unknown Player |
| HistoryManager | лента бросков |
| PredictionStore | JSON persistence |
| RegionSelector | crash-safe AppKit overlay |
| PredictionOverlay | плавающее окно ТОП-4 |

## Region Selector (anti-crash)

Предыдущая версия падала с `EXC_BAD_ACCESS` при выборе области игрока.

Защиты:

- чистый AppKit (без SwiftUI `NSViewRepresentable`)
- `isReleasedWhenClosed = false`
- `weak self` в `trackEvents`
- self-retain контроллера до dismiss
- callback после teardown на следующем runloop tick
- отложенный `contentView = nil`
- запрет re-entrancy во время tracking

## Производительность (8 GB Intel)

- Result capture ≈ 8 FPS
- Player capture ≈ 6 FPS, max width 320px
- OCR `.fast`, без language correction
- Инкрементальное обучение (без full retrain)
- История в RAM до 2000 записей
- Фоновые очереди / actors для OCR и Vision

## Честность метрик

Уверенность и проценты точности считаются только по реальным SUCCESS/MISS. Промахи не удаляются и не скрываются.

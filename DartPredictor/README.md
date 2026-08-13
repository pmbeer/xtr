# DartPredictor

Нативное macOS-приложение для прогнозирования результатов дартса в реальном времени.

## Возможности

- Захват выбранных областей экрана (ScreenCaptureKit)
- OCR распознавание результатов (Vision Framework)
- Анализ поведения игрока (поза, замах, ритм)
- Ансамбль 5 моделей с адаптивными весами
- Online learning после каждого броска
- TOP-4 прогноз с нормализованными процентами
- Paper Prediction — тестирование без ставок
- Плавающее окно с прогнозом
- Локальное сохранение обучения

## Быстрый старт

```bash
cd DartPredictor
./scripts/build_dmg.sh
open build/DartPredictor.dmg
```

## Документация

- [Установка](docs/INSTALL.md)
- [Первый запуск](docs/FIRST_RUN.md)
- [Архитектура](docs/ARCHITECTURE.md)

## Системные требования

- macOS 14.0+
- Intel x86_64 (оптимизировано для MacBook Pro 2018, 8 GB RAM)
- Разрешение на запис экрана

## Структура проекта

```
DartPredictor/
├── DartPredictor.xcodeproj
├── DartPredictor/
│   ├── App/              # Точка входа
│   ├── Core/
│   │   ├── Capture/      # ScreenCaptureKit
│   │   ├── OCR/          # Vision OCR
│   │   ├── Vision/       # Анализ игрока
│   │   ├── Detection/    # Throw detection
│   │   ├── Models/       # Модели A–E
│   │   ├── Learning/     # Ensemble + обучение
│   │   ├── Pipeline/     # Оркестрация
│   │   ├── Storage/      # Персистентность
│   │   └── Accuracy/     # Статистика
│   ├── UI/               # SwiftUI интерфейс
│   └── Resources/        # Иконки, assets
├── DartPredictorTests/   # Unit-тесты
├── scripts/              # Сборка и генерация
└── docs/                 # Документация
```

## Важно

Приложение **не выполняет автоматические ставки**. Оно только анализирует экран и показывает прогнозы. Точность отображается честно — без искусственного завышения процентов.

## Лицензия

Proprietary — все права защищены.

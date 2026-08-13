# Установка DartPredictor

## Требования

- macOS 14.0 или новее (протестировано на macOS 15.7.8)
- Mac с архитектурой Intel x86_64 (MacBook Pro 2018 и аналоги)
- Xcode 15+ для сборки из исходников
- Разрешение на запис экрана в Системных настройках

## Установка из DMG

1. Откройте файл `DartPredictor.dmg` из папки `build/`.
2. Перетащите `DartPredictor.app` в папку Applications.
3. При первом запуске macOS может запросить подтверждение — откройте **Системные настройки → Конфиденциальность и безопасность** и разрешите запуск.
4. Предоставьте разрешение на **Запись экрана** (см. FIRST_RUN.md).

## Сборка из исходников

```bash
cd DartPredictor
chmod +x scripts/*.sh
./scripts/build_dmg.sh
```

Результат:

- `build/DartPredictor.app` — готовое приложение
- `build/DartPredictor.dmg` — установщик

### Сборка в Xcode

1. Откройте `DartPredictor.xcodeproj`.
2. Выберите схему **DartPredictor**.
3. Установите архитектуру **My Mac (Intel)** или `x86_64`.
4. Product → Build (⌘B) или Archive для распространения.

### Регенерация Xcode проекта

Если добавлены новые файлы:

```bash
python3 scripts/generate_xcodeproj.py
```

### Генерация иконок

```bash
./scripts/generate_icons.sh
```

## Обновление

Замените `DartPredictor.app` в Applications новой версией. Данные обучения сохраняются в:

```
~/Library/Application Support/DartPredictor/
```

## Удаление

1. Удалите `DartPredictor.app` из Applications.
2. (Опционально) удалите данные: `rm -rf ~/Library/Application\ Support/DartPredictor`

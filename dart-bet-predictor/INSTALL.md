# Установка на MacBook Pro 2018 (Intel, 8 ГБ, macOS Sequoia)

## Прямая ссылка (v1.0.2 — Universal, Intel + Apple Silicon)

**https://github.com/pmbeer/xtr/releases/download/dart-bet-predictor-v1.0.2/DartBetPredictor-1.0.2-macOS-Universal.dmg**

> Если ссылка ещё не активна — соберите на Mac (см. ниже) или скачайте из [Actions](https://github.com/pmbeer/xtr/actions).

---

## Ваш Mac

| Параметр | Значение |
|----------|----------|
| Модель | MacBook Pro 13" 2018 |
| Процессор | Intel Core i5 2.3 GHz (4 ядра) |
| Память | 8 ГБ |
| macOS | Sequoia 15.7.8 |
| Архитектура | **x86_64 (Intel)** |

Приложение **автоматически** определяет Intel Mac и:
- снижает нагрузку на CPU (интервал OCR 220 мс вместо 150)
- анализирует игрока реже (каждый 3-й кадр)
- уменьшает разрешение анализа движения (120×90)

---

## Установка

1. Скачайте DMG по ссылке выше
2. Откройте файл
3. Перетащите **DartBetPredictor** в **Applications**
4. Запустите из Программ

### Первый запуск

- **«Разработчик не подтверждён»** → ПКМ → **Открыть** → **Открыть**
- **Запись экрана** → Системные настройки → Конфиденциальность → Запись экрана → включите DartBetPredictor → перезапустите

---

## Собрать на своём Mac (если DMG не подходит)

```bash
git clone https://github.com/pmbeer/xtr.git
cd xtr/dart-bet-predictor
chmod +x build-installer.sh
./build-installer.sh
open dist/DartBetPredictor-1.0.2-macOS-Universal.dmg
```

На Intel Mac соберётся нативный **x86_64** бинарник — оптимально для вашего железа.

---

## Удаление

Перетащите `DartBetPredictor.app` в Корзину.

Данные обучения: `~/Library/Application Support/DartBetPredictor/`

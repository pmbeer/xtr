# Установка Dart Bet Predictor на MacBook

## Способ 1: Скачать готовый установщик (рекомендуется)

### Из GitHub Actions (после сборки)

1. Откройте вкладку **Actions** в репозитории на GitHub
2. Выберите workflow **Build macOS Installer**
3. Откройте последний успешный запуск (зелёная галочка)
4. Внизу страницы в разделе **Artifacts** скачайте:
   - `DartBetPredictor-macOS-Installer` — файл `.dmg` (установщик)
5. Откройте скачанный `.dmg`
6. Перетащите **DartBetPredictor** в папку **Applications**

### Из GitHub Releases (если опубликован релиз)

1. Перейдите в **Releases** репозитория
2. Скачайте `DartBetPredictor-1.0.0-macOS.dmg`
3. Установите как описано выше

---

## Способ 2: Собрать на своём MacBook

Если у вас есть исходники:

```bash
cd dart-bet-predictor
chmod +x build-installer.sh
./build-installer.sh
```

Готовый установщик появится здесь:
```
dart-bet-predictor/dist/DartBetPredictor-1.0.0-macOS.dmg
```

Требуется: Xcode Command Line Tools (`xcode-select --install`)

---

## Первый запуск

1. Откройте **DartBetPredictor** из папки Программы
2. Если macOS пишет «разработчик не подтверждён»:
   - ПКМ на приложении → **Открыть** → **Открыть**
3. Разрешите **Запись экрана**:
   - **Системные настройки → Конфиденциальность и безопасность → Запись экрана**
   - Включите DartBetPredictor
   - Перезапустите приложение
4. В строке меню появится иконка мишени — кликните для настройки

---

## Быстрая настройка

1. **Выбрать СЕРИЮ** — область с историей бросков
2. **Выбрать игрока** — видео с ведущим
3. Нажать **Старт**
4. Окно прогноза — расположить рядом с игрой

---

## Удаление

Перетащите `DartBetPredictor.app` из Applications в Корзину.

Данные обучения хранятся в:
```
~/Library/Application Support/DartBetPredictor/
```

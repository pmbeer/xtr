# Wink — шаблон для DataLife Engine

Копия дизайна **[wink.ru](https://wink.ru)** для CMS DataLife Engine.

## Особенности дизайна

- Тёмный фон `#0E0C0E` / чёрный
- Оранжевый акцент `#FF5A24` (фирменный цвет Wink)
- Pill-кнопки (`border-radius: 999px`)
- Белая «таблетка» для активного пункта меню
- Промо-полоса сверху (как на Wink)
- Hero-слайдер с бейджем «Смотрите в подписке»
- Карусели: **Новинки**, **Выбор зрителей**, **Лучшее в HD**
- Шрифты CoFo Sans / CoFo Kak (с fallback на Manrope)

## Установка

1. Скачайте `dle_streamx.zip`
2. Распакуйте и загрузите папку `dle_streamx` в `/templates/`
3. В админке DLE: **Настройки → Система** → шаблон `dle_streamx`
4. Очистите кэш

## Превью локально

Откройте `dle_streamx/preview.html` в браузере для просмотра дизайна без DLE.

## Настройка категорий

Создайте категории с URL:

| Раздел    | URL slug |
|-----------|----------|
| ТВ-каналы | `tv`     |
| Фильмы    | `films`  |
| Сериалы   | `series` |
| Детям     | `kids`   |
| Спорт     | `sport`  |

Меню `{catmenu}` добавляет категории из DLE автоматически.

## Дополнительные поля

| Поле       | Тип  | Описание         |
|------------|------|------------------|
| `year`     | Текст | Год выпуска     |
| `genre`    | Текст | Жанр            |
| `duration` | Текст | Длительность    |
| `quality`  | Список | HD / 4K        |
| `iframe`   | HTML  | Код плеера      |

## Структура

```
dle_streamx/
├── main.tpl
├── shortstory-poster.tpl
├── shortstory-hero.tpl
├── fullstory.tpl
├── css/styles.css
├── js/app.js
├── images/wink-logo.svg
└── preview.html
```

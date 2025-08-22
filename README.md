# Wink Clone (PHP 8.2, MVC)

## Установка
1. Загрузите файлы проекта на хостинг в корневую директорию сайта. Папка `public` должна быть настроена как веб-корень (DocumentRoot).
2. Создайте пустую БД MySQL/MariaDB (например, `wink_clone`) c кодировкой utf8mb4.
3. Импортируйте дамп `database/schema.sql` в вашу БД.
4. Откройте `config/db.php` и укажите параметры подключения к БД (host, database, username, password). При необходимости включите `display_errors` в режиме разработки.
5. Убедитесь, что для Apache включен модуль `mod_rewrite`, `.htaccess` разрешён и `public/.htaccess` активен. Для Nginx настройте rewrite на `public/index.php`.
6. Перейдите в браузере на ваш домен. Войдите под администратором: `admin@example.com`, пароль: `admin123` (см. ниже). Либо зарегистрируйте нового пользователя.

### Данные по умолчанию
- Админ: admin@example.com / admin123
- Демо контент, баннеры, ТВ-каналы доступны сразу после импорта дампа.

## Стек и структура
- PHP 8.2+, PDO (MySQL), MVC, чистые Views на PHP
- Защита: password_hash, подготовленные выражения, XSS-экранирование, CSRF
- Плеер: Video.js CDN

## Структура
- `public/` — веб-корень (index.php, assets, .htaccess)
- `core/` — ядро (bootstrap, Router, Controller, Model, Security, Helpers)
- `config/` — конфиг БД и приложения
- `app/Controllers` — контроллеры
- `app/Models` — модели
- `app/views` — представления
- `database/schema.sql` — схема и сиды
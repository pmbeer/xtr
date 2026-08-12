# Wink Clone — standalone онлайн-кинотеатр

Полноценный standalone-клон [wink.ru](https://wink.ru): PHP 8.2 MVC-приложение с дизайном Wink (оранжевый акцент, тёмная тема, карусели, промо-бар, плеер).

## Возможности

- **Главная** — hero-слайдер, «Продолжить просмотр», ряды «Новинки», «Выбор зрителей», СТС/ТНТ, Wink Originals
- **Каталог** — фильмы, сериалы, детский раздел, спорт
- **ТВ-каналы** — список каналов с EPG-заглушкой и страница просмотра
- **Карточка контента** — постер, рейтинги, актёры, сезоны и серии
- **Плеер** — Video.js, HLS-демо, прогресс просмотра
- **Подписки** — тарифы Wink, оформление (демо без реальной оплаты)
- **Авторизация** — вход по телефону (демо) и email/пароль, регистрация
- **Личный кабинет** — профиль, история, мой список
- **Поиск** — по названию контента
- **Админка** — управление контентом и пользователями (`/admin`)

## Быстрый старт (Docker)

```bash
git clone <repo>
cd <repo>
docker compose up -d --build
```

Откройте http://localhost:8080

- phpMyAdmin: http://localhost:8081 (логин `wink` / `wink`)
- Админ: `admin@example.com` / `admin123` или телефон `9001234567`
- БД инициализируется из `database/schema.sql` при первом запуске

## Установка на хостинг

1. Загрузите файлы проекта. **DocumentRoot** должен указывать на папку `public/`.
2. Создайте БД MySQL/MariaDB `wink_clone` (utf8mb4).
3. Импортируйте `database/schema.sql`.
4. Скопируйте `.env.example` в `.env` и укажите параметры БД (или отредактируйте `config/db.php`).
5. Включите `mod_rewrite` (Apache) или настройте rewrite на `public/index.php` (Nginx).

### Nginx (пример)

```nginx
root /var/www/wink-clone/public;
index index.php;
location / {
    try_files $uri $uri/ /index.php?$query_string;
}
location ~ \.php$ {
    fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
}
```

## Стек

| Компонент | Технология |
|-----------|------------|
| Backend | PHP 8.2+, PDO, MVC |
| БД | MySQL / MariaDB |
| Frontend | Wink CSS/JS, Video.js |
| Безопасность | `password_hash`, prepared statements, CSRF, XSS-экранирование |

## Структура проекта

```
├── public/           # веб-корень (index.php, assets)
├── app/
│   ├── Controllers/  # Home, Media, Tv, Sport, Auth, Subscribe, Admin…
│   ├── Models/
│   └── views/
├── core/             # Router, Controller, Model, Security
├── config/db.php     # конфиг (поддержка env-переменных)
├── database/schema.sql
├── docker-compose.yml
└── Dockerfile
```

## Ограничения (демо)

Это UI/UX-клон для хостинга, а не интеграция с реальным Wink:

- SMS-авторизация — заглушка (демо-номер в сиде)
- Платежи — без реальных эквайрингов
- IPTV/EPG — демо-данные
- Рекомендации — статические выборки из БД

## Лицензия

Учебный/демо-проект. Бренд Wink принадлежит АО «РТК».

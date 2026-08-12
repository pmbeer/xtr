<?php
return [
    'app' => [
        'name' => 'Wink Clone',
        'env' => getenv('APP_ENV') ?: 'production',
        'timezone' => getenv('APP_TIMEZONE') ?: 'Europe/Moscow',
        'display_errors' => filter_var(getenv('APP_DEBUG') ?: '0', FILTER_VALIDATE_BOOL),
    ],
    'db' => [
        'host' => getenv('DB_HOST') ?: '127.0.0.1',
        'port' => (int)(getenv('DB_PORT') ?: 3306),
        'database' => getenv('DB_DATABASE') ?: 'wink_clone',
        'username' => getenv('DB_USERNAME') ?: 'root',
        'password' => getenv('DB_PASSWORD') ?: '',
    ],
];
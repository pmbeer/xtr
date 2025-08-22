<?php
declare(strict_types=1);

namespace Core;

// Define base path
\define('BASE_PATH', dirname(__DIR__));

// Simple PSR-4 like autoloader for Core and App namespaces
\spl_autoload_register(function (string $class): void {
    $prefixes = [
        'Core\\' => BASE_PATH . '/core/',
        'App\\' => BASE_PATH . '/app/',
    ];
    foreach ($prefixes as $prefix => $baseDir) {
        $len = \strlen($prefix);
        if (\strncmp($prefix, $class, $len) !== 0) {
            continue;
        }
        $relativeClass = \substr($class, $len);
        $file = $baseDir . str_replace('\\', '/', $relativeClass) . '.php';
        if (is_file($file)) {
            require $file;
        }
    }
});

// Include helper files (no namespaces)
require_once BASE_PATH . '/core/Helpers.php';
require_once BASE_PATH . '/core/Security.php';

// Load config
$config = require BASE_PATH . '/config/db.php';

// Start secure session
if (session_status() !== PHP_SESSION_ACTIVE) {
    \session_set_cookie_params([
        'httponly' => true,
        'secure' => isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off',
        'samesite' => 'Lax',
        'path' => '/',
    ]);
    \session_start();
}

// Set timezone and error modes
\date_default_timezone_set($config['app']['timezone'] ?? 'UTC');
\ini_set('display_errors', $config['app']['display_errors'] ? '1' : '0');
\error_reporting(E_ALL & ~E_NOTICE);

// Create PDO connection
try {
    $dsn = sprintf('mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
        $config['db']['host'],
        (string)($config['db']['port'] ?? 3306),
        $config['db']['database']
    );
    $pdo = new \PDO($dsn, $config['db']['username'], $config['db']['password'], [
        \PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION,
        \PDO::ATTR_DEFAULT_FETCH_MODE => \PDO::FETCH_ASSOC,
        \PDO::ATTR_EMULATE_PREPARES => false,
    ]);
} catch (\Throwable $e) {
    http_response_code(500);
    echo 'Database connection failed.';
    exit;
}

// Simple service container
$container = [
    'config' => $config,
    'pdo' => $pdo,
];
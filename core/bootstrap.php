<?php

declare(strict_types=1);

// Composer autoload if available (not required)
$vendorAutoload = __DIR__ . '/../vendor/autoload.php';
if (file_exists($vendorAutoload)) {
	require $vendorAutoload;
}

// PSR-4 like simple autoloader for Core, Controllers, Models
spl_autoload_register(function (string $class): void {
	$prefixes = [
		'Core' => __DIR__,
		'Controllers' => __DIR__ . '/../controllers',
		'Models' => __DIR__ . '/../models',
	];
	foreach ($prefixes as $prefix => $baseDir) {
		$len = strlen($prefix . '\\');
		if (strncmp($prefix . '\\', $class, $len) !== 0) {
			continue;
		}
		$relative = substr($class, $len);
		$file = $baseDir . '/' . str_replace('\\', '/', $relative) . '.php';
		if (file_exists($file)) {
			require $file;
		}
	}
});

// Start secure session
ini_set('session.use_strict_mode', '1');
ini_set('session.cookie_httponly', '1');
ini_set('session.cookie_samesite', 'Lax');
if (!empty($_SERVER['HTTPS'])) {
	ini_set('session.cookie_secure', '1');
}
session_start();

// Load config
require __DIR__ . '/../config/db.php';

// Setup global error handling (production-safe by default)
set_error_handler(function ($severity, $message, $file, $line) {
	if (!(error_reporting() & $severity)) {
		return false;
	}
	throw new ErrorException($message, 0, $severity, $file, $line);
});

set_exception_handler(function (Throwable $e) {
	http_response_code(500);
	if (getenv('APP_DEBUG') === '1') {
		echo '<pre>' . htmlspecialchars($e->getMessage()) . "\n" . htmlspecialchars($e->getTraceAsString()) . '</pre>';
	} else {
		echo 'Internal Server Error';
	}
});

// Initialize shared services
Core\DB::init($config['db']);
Core\Security::ensureCsrfToken();
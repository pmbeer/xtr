<?php

declare(strict_types=1);

spl_autoload_register(function (string $class): void {
	$prefixes = [
		'Core' => __DIR__,
		'Controllers' => __DIR__ . '/../controllers',
		'Models' => __DIR__ . '/../models',
	];
	$parts = explode('\\\
', $class);
	$root = array_shift($parts);
	$path = $prefixes[$root] ?? null;
	if ($path === null) {
		return;
	}
	$file = $path . '/' . implode('/', $parts) . '.php';
	if (is_file($file)) {
		require $file;
	}
});

use Core\Config;
use Core\DB;
use Core\Session;
use Core\CSRF;

require __DIR__ . '/../config/app.php';
require __DIR__ . '/../config/db.php';

Config::set('app', $APP_CONFIG ?? []);
Config::set('db', $DB_CONFIG ?? []);

Session::start();
CSRF::init();
DB::init(Config::get('db'));
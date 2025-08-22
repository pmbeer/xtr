<?php

$config = [
	'db' => [
		'host' => getenv('DB_HOST') ?: 'localhost',
		'port' => (int)(getenv('DB_PORT') ?: 3306),
		'database' => getenv('DB_NAME') ?: 'wink_clone',
		'user' => getenv('DB_USER') ?: 'root',
		'password' => getenv('DB_PASS') ?: '',
	],
];
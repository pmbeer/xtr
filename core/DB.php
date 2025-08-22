<?php

declare(strict_types=1);

namespace Core;

use PDO;
use PDOException;

final class DB
{
	private static ?PDO $pdo = null;

	public static function init(array $config): void
	{
		if (self::$pdo !== null) {
			return;
		}
		$dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
			$config['host'],
			$config['port'] ?? 3306,
			$config['database']
		);
		$options = [
			PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
			PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
			PDO::ATTR_EMULATE_PREPARES => false,
		];
		try {
			self::$pdo = new PDO($dsn, $config['user'], $config['password'], $options);
		} catch (PDOException $e) {
			http_response_code(500);
			exit('Database connection failed');
		}
	}

	public static function pdo(): PDO
	{
		if (self::$pdo === null) {
			throw new \RuntimeException('DB not initialized');
		}
		return self::$pdo;
	}
}
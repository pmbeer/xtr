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
		$dsn = sprintf('mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
			$config['host'] ?? '127.0.0.1',
			(string)($config['port'] ?? '3306'),
			$config['database'] ?? ''
		);
		$options = [
			PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
			PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
			PDO::ATTR_EMULATE_PREPARES => false,
		];
		try {
			self::$pdo = new PDO($dsn, $config['username'] ?? 'root', $config['password'] ?? '', $options);
		} catch (PDOException $e) {
			http_response_code(500);
			echo 'Database connection failed';
			exit;
		}
	}

	public static function pdo(): PDO
	{
		if (!self::$pdo) {
			throw new \RuntimeException('DB not initialized');
		}
		return self::$pdo;
	}

	public static function query(string $sql, array $params = []): \PDOStatement
	{
		$stmt = self::pdo()->prepare($sql);
		$stmt->execute($params);
		return $stmt;
	}
}
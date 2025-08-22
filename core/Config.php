<?php

declare(strict_types=1);

namespace Core;

final class Config
{
	private static array $items = [];

	public static function set(string $key, array $value): void
	{
		self::$items[$key] = $value;
	}

	public static function get(string $key, ?string $subKey = null, mixed $default = null): mixed
	{
		if (!array_key_exists($key, self::$items)) {
			return $default;
		}
		if ($subKey === null) {
			return self::$items[$key];
		}
		return self::$items[$key][$subKey] ?? $default;
	}
}
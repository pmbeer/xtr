<?php

declare(strict_types=1);

namespace Core;

final class Session
{
	public static function start(): void
	{
		if (session_status() !== PHP_SESSION_ACTIVE) {
			session_start();
		}
	}

	public static function get(string $key, mixed $default = null): mixed
	{
		return $_SESSION[$key] ?? $default;
	}

	public static function set(string $key, mixed $value): void
	{
		$_SESSION[$key] = $value;
	}

	public static function flash(string $key, ?string $value = null): ?string
	{
		if ($value === null) {
			$v = $_SESSION['_flash'][$key] ?? null;
			unset($_SESSION['_flash'][$key]);
			return $v;
		}
		$_SESSION['_flash'][$key] = $value;
		return null;
	}

	public static function destroy(): void
	{
		$_SESSION = [];
		if (ini_get('session.use_cookies')) {
			$params = session_get_cookie_params();
			setcookie(session_name(), '', time() - 42000, $params['path'], $params['domain'], $params['secure'], $params['httponly']);
		}
		session_destroy();
	}
}
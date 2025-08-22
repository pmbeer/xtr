<?php

declare(strict_types=1);

namespace Core;

use Core\DB;

final class Auth
{
	public static function attempt(string $email, string $password): bool
	{
		$user = DB::query('SELECT * FROM users WHERE email = ?', [$email])->fetch();
		if ($user && password_verify($password, $user['password_hash'])) {
			$_SESSION['user_id'] = (int)$user['id'];
			$_SESSION['is_admin'] = (bool)$user['is_admin'];
			return true;
		}
		return false;
	}

	public static function check(): bool
	{
		return isset($_SESSION['user_id']);
	}

	public static function id(): ?int
	{
		return self::check() ? (int)$_SESSION['user_id'] : null;
	}

	public static function logout(): void
	{
		Session::destroy();
	}

	public static function userIsAdmin(): bool
	{
		return (bool)($_SESSION['is_admin'] ?? false);
	}
}
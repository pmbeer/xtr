<?php

declare(strict_types=1);

namespace Core;

final class Security
{
	public static function ensureCsrfToken(): void
	{
		if (empty($_SESSION['_csrf'])) {
			$_SESSION['_csrf'] = bin2hex(random_bytes(32));
		}
	}

	public static function csrfToken(): string
	{
		return (string)($_SESSION['_csrf'] ?? '');
	}

	public static function validateCsrfToken(string $token): void
	{
		if (!hash_equals(self::csrfToken(), $token)) {
			http_response_code(400);
			exit('Invalid CSRF token');
		}
	}

	public static function e(?string $value): string
	{
		return htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
	}
}
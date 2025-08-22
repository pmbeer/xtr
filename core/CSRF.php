<?php

declare(strict_types=1);

namespace Core;

final class CSRF
{
	public static function init(): void
	{
		if (!isset($_SESSION['_csrf'])) {
			$_SESSION['_csrf'] = bin2hex(random_bytes(32));
		}
	}

	public static function token(): string
	{
		return (string)($_SESSION['_csrf'] ?? '');
	}

	public static function field(): string
	{
		$token = self::token();
		return '<input type="hidden" name="_csrf" value="' . htmlspecialchars($token, ENT_QUOTES, 'UTF-8') . '">';
	}

	public static function validate(): void
	{
		$token = $_POST['_csrf'] ?? '';
		if (!hash_equals(self::token(), (string)$token)) {
			http_response_code(419);
			echo 'CSRF token mismatch';
			exit;
		}
	}
}
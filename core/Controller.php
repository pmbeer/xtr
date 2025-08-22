<?php

declare(strict_types=1);

namespace Core;

abstract class Controller
{
	protected function view(string $template, array $data = []): void
	{
		extract($data, EXTR_OVERWRITE);
		$__template = __DIR__ . '/../views/' . $template . '.php';
		if (!is_file($__template)) {
			throw new \RuntimeException('View not found: ' . $template);
		}
		require __DIR__ . '/../views/layouts/header.php';
		require $__template;
		require __DIR__ . '/../views/layouts/footer.php';
	}

	protected function json(array $payload, int $status = 200): void
	{
		http_response_code($status);
		header('Content-Type: application/json; charset=utf-8');
		echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
	}

	protected function redirect(string $url): void
	{
		header('Location: ' . $url);
		exit;
	}

	protected function requireAuth(): void
	{
		if (!Auth::check()) {
			$this->redirect('/login');
		}
	}

	protected function requireAdmin(): void
	{
		if (!Auth::check() || !Auth::userIsAdmin()) {
			http_response_code(403);
			echo 'Forbidden';
			exit;
		}
	}
}
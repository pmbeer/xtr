<?php

declare(strict_types=1);

namespace Core;

class Controller
{
	protected function view(string $template, array $params = []): void
	{
		extract($params, EXTR_SKIP);
		$viewFile = __DIR__ . '/../views/' . $template . '.php';
		$layout = __DIR__ . '/../views/layouts/main.php';
		ob_start();
		require $viewFile;
		$content = ob_get_clean();
		require $layout;
	}

	protected function redirect(string $path): void
	{
		header('Location: ' . $path);
		exit;
	}

	protected function requirePost(): void
	{
		if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
			http_response_code(405);
			exit('Method Not Allowed');
		}
	}

	protected function validateCsrf(): void
	{
		Security::validateCsrfToken($_POST['_csrf'] ?? '');
	}

	protected function currentUserId(): ?int
	{
		return $_SESSION['user_id'] ?? null;
	}

	protected function requireAuth(): void
	{
		if (!$this->currentUserId()) {
			$this->redirect('/login');
		}
	}
}
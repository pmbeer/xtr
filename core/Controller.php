<?php
declare(strict_types=1);

namespace Core;

abstract class Controller
{
    protected array $container;
    protected \PDO $pdo;

    public function __construct(array $container)
    {
        $this->container = $container;
        $this->pdo = $container['pdo'];
    }

    protected function render(string $view, array $params = [], string $layout = 'layouts/main'): void
    {
        extract($params, EXTR_OVERWRITE);
        $viewFile = BASE_PATH . '/app/views/' . trim($view, '/') . '.php';
        $layoutFile = BASE_PATH . '/app/views/' . trim($layout, '/') . '.php';
        if (!is_file($viewFile)) {
            http_response_code(500);
            echo 'View not found';
            return;
        }
        ob_start();
        include $viewFile; // view will use $this->section to capture blocks
        $content = ob_get_clean();
        include $layoutFile;
    }

    protected function redirect(string $path): void
    {
        header('Location: ' . url($path));
        exit;
    }

    protected function json(array $data, int $status = 200): void
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }
}
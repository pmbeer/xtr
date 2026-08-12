<?php
declare(strict_types=1);

require dirname(__DIR__) . '/core/bootstrap.php';

$router = new Core\Router($container);
$router->dispatch($_SERVER['REQUEST_URI'] ?? '/', $_SERVER['REQUEST_METHOD'] ?? 'GET');
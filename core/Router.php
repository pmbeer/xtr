<?php
declare(strict_types=1);

namespace Core;

final class Router
{
    private array $routes = ['GET' => [], 'POST' => []];
    private array $container;

    public function __construct(array $container)
    {
        $this->container = $container;
    }

    public function get(string $path, string $handler): void
    {
        $this->routes['GET'][$this->normalize($path)] = $handler;
    }

    public function post(string $path, string $handler): void
    {
        $this->routes['POST'][$this->normalize($path)] = $handler;
    }

    public function dispatch(string $uri, string $method): void
    {
        $path = $this->normalize(parse_url($uri, PHP_URL_PATH) ?: '/');
        $method = strtoupper($method);

        // Match explicit route
        if (isset($this->routes[$method][$path])) {
            $this->invokeHandler($this->routes[$method][$path]);
            return;
        }

        // Auto-mapping: /controller/action/param1/param2
        $segments = array_values(array_filter(explode('/', trim($path, '/'))));
        $controllerSegment = $segments[0] ?? 'home';
        $actionSegment = $segments[1] ?? 'index';
        $params = array_slice($segments, 2);

        $controllerClass = 'App\\Controllers\\' . ucfirst($controllerSegment) . 'Controller';
        $actionMethod = $this->toCamel($actionSegment);

        if (!class_exists($controllerClass)) {
            http_response_code(404);
            echo 'Controller not found';
            return;
        }
        $controller = new $controllerClass($this->container);
        if (!method_exists($controller, $actionMethod)) {
            http_response_code(404);
            echo 'Action not found';
            return;
        }

        if ($method === 'POST' && !\Security::verifyCsrfToken($_POST['csrf_token'] ?? '')) {
            http_response_code(419);
            echo 'Invalid CSRF token';
            return;
        }

        \call_user_func_array([$controller, $actionMethod], $params);
    }

    private function normalize(string $path): string
    {
        if ($path === '') { return '/'; }
        return '/' . trim($path, '/');
    }

    private function toCamel(string $kebab): string
    {
        $kebab = str_replace(['-', '_'], ' ', strtolower($kebab));
        $camel = lcfirst(str_replace(' ', '', ucwords($kebab)));
        return $camel;
    }
}
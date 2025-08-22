<?php

declare(strict_types=1);

namespace Core;

class Router
{
	private array $routes = [
		'GET' => [],
		'POST' => [],
	];

	public function get(string $path, string $action): void
	{
		$this->routes['GET'][$this->normalize($path)] = $action;
	}

	public function post(string $path, string $action): void
	{
		$this->routes['POST'][$this->normalize($path)] = $action;
	}

	public function dispatch(string $method, string $path): void
	{
		$method = strtoupper($method);
		$path = $this->normalize($path);
		$action = $this->routes[$method][$path] ?? null;
		if ($action === null) {
			http_response_code(404);
			echo 'Page not found';
			return;
		}
		[$controllerName, $methodName] = explode('@', $action);
		$controllerClass = 'Controllers\\' . $controllerName;
		if (!class_exists($controllerClass)) {
			throw new \RuntimeException('Controller not found: ' . $controllerClass);
		}
		$controller = new $controllerClass();
		if (!method_exists($controller, $methodName)) {
			throw new \RuntimeException('Method not found: ' . $controllerClass . '::' . $methodName);
		}
		$controller->{$methodName}();
	}

	private function normalize(string $path): string
	{
		if ($path === '') {
			return '/';
		}
		if ($path[0] !== '/') {
			$path = '/' . $path;
		}
		return rtrim($path, '/') ?: '/';
	}
}
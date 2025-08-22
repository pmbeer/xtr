<?php

declare(strict_types=1);

namespace Core;

final class Router
{
	private array $routes = [];
	private string $groupPrefix = '';

	public function group(string $prefix, callable $callback): void
	{
		$previous = $this->groupPrefix;
		$this->groupPrefix .= rtrim($prefix, '/');
		$callback($this);
		$this->groupPrefix = $previous;
	}

	public function get(string $path, string $handler): void
	{
		$this->map('GET', $path, $handler);
	}

	public function post(string $path, string $handler): void
	{
		$this->map('POST', $path, $handler);
	}

	private function map(string $method, string $path, string $handler): void
	{
		$fullPath = $this->groupPrefix . ($path === '' ? '' : $path);
		$this->routes[$method][] = [$this->compile($fullPath), $handler];
	}

	private function compile(string $path): array
	{
		$path = '/' . ltrim($path, '/');
		$pattern = preg_replace('#\{([a-zA-Z_][a-zA-Z0-9_]*)\}#', '(?P<$1>[^/]+)', $path);
		return ['#^' . $pattern . '$#', $path];
	}

	public function dispatch(): void
	{
		$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
		$uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
		$routes = $this->routes[$method] ?? [];
		foreach ($routes as [$compiled, $handler]) {
			[$regex] = $compiled;
			if (preg_match($regex, $uri, $matches)) {
				$params = [];
				foreach ($matches as $k => $v) {
					if (!is_int($k)) {
						$params[$k] = $v;
					}
				}
				return $this->invoke($handler, $params);
			}
		}
		http_response_code(404);
		echo '404 Not Found';
	}

	private function invoke(string $handler, array $params): void
	{
		[$class, $method] = explode('@', $handler, 2);
		if (!str_contains($class, '\\')) {
			$class = 'Controllers\\' . $class;
		}
		if (!class_exists($class)) {
			throw new \RuntimeException("Controller $class not found");
		}
		$controller = new $class();
		if (!method_exists($controller, $method)) {
			throw new \RuntimeException("Method $method not found in $class");
		}
		$controller->$method($params);
	}
}
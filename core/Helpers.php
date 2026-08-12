<?php
declare(strict_types=1);

function e(?string $value): string {
    return htmlspecialchars($value ?? '', ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function url(string $path = '/'): string {
    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    $base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
    return $scheme . '://' . $host . $base . '/' . ltrim($path, '/');
}

function asset(string $path): string {
    $full = __DIR__ . '/../public/' . ltrim($path, '/');
    $ver = is_file($full) ? (string)filemtime($full) : '1';
    return url($path) . '?v=' . $ver;
}

function auth_user(): ?array {
    return $_SESSION['user'] ?? null;
}

function is_authenticated(): bool {
    return isset($_SESSION['user']);
}

function require_auth(): void {
    if (!is_authenticated()) {
        header('Location: ' . url('/auth/login'));
        exit;
    }
}
<?php
declare(strict_types=1);

namespace App\Controllers;

use Core\Controller;

final class SearchController extends Controller
{
    public function index(): void
    {
        $q = trim((string)($_GET['q'] ?? ''));
        $items = [];
        if ($q !== '') {
            $stmt = $this->pdo->prepare("SELECT id, title, poster_url, year FROM content WHERE title LIKE ? ORDER BY updated_at DESC, created_at DESC LIMIT 100");
            $stmt->execute(['%' . $q . '%']);
            $items = $stmt->fetchAll();
        }
        $this->render('catalog/index', ['title' => 'Поиск: ' . e($q), 'items' => $items]);
    }
}
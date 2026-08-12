<?php
declare(strict_types=1);

namespace App\Controllers;

use Core\Controller;
use App\Models\ContentModel;

final class MoviesController extends Controller
{
    public function index(): void
    {
        $model = new ContentModel($this->pdo);
        $filters = [
            'genre' => $_GET['genre'] ?? null,
            'year' => isset($_GET['year']) ? (int)$_GET['year'] : null,
            'country' => $_GET['country'] ?? null,
        ];
        $items = $model->listByType('movie', $filters);
        $this->render('catalog/index', ['title' => 'Фильмы', 'items' => $items]);
    }
}
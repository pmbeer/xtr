<?php
declare(strict_types=1);

namespace App\Controllers;

use Core\Controller;
use App\Models\ContentModel;

final class SearchController extends Controller
{
    public function index(): void
    {
        $q = trim((string)($_GET['q'] ?? ''));
        $content = new ContentModel($this->pdo);
        $items = $q !== '' ? $content->search($q) : [];
        $newReleases = $q === '' ? $content->getLatestMovies(16) : [];
        $topSeries = $q === '' ? $content->getLatestSeries(16) : [];
        $this->render('search/index', compact('q', 'items', 'newReleases', 'topSeries'));
    }
}

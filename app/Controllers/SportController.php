<?php
declare(strict_types=1);

namespace App\Controllers;

use Core\Controller;
use App\Models\ContentModel;

final class SportController extends Controller
{
    public function index(): void
    {
        $content = new ContentModel($this->pdo);
        $this->render('sport/index', [
            'pageTitle' => 'Спорт — Wink',
            'showPromo' => false,
            'live' => $content->listByType('movie', ['tag' => 'sport']),
            'featured' => $content->getFeatured(12),
        ]);
    }
}

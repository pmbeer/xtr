<?php
declare(strict_types=1);

namespace App\Controllers;

use Core\Controller;
use App\Models\ContentModel;

final class TvController extends Controller
{
    public function index(): void
    {
        $model = new ContentModel($this->pdo);
        $items = $model->getTvChannels();
        $this->render('catalog/tv', ['title' => 'ТВ-каналы', 'items' => $items]);
    }
}
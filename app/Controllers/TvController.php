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
        $this->render('catalog/tv', ['items' => $model->getTvChannels()]);
    }

    public function watch(int $id): void
    {
        $stmt = $this->pdo->prepare('SELECT * FROM tv_channels WHERE id = ? AND is_active = 1');
        $stmt->execute([$id]);
        $channel = $stmt->fetch();
        if (!$channel) { http_response_code(404); echo 'Канал не найден'; return; }
        $this->render('tv/watch', ['channel' => $channel]);
    }
}

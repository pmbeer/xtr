<?php
declare(strict_types=1);

namespace App\Controllers;

use Core\Controller;
use App\Models\MediaModel;

final class MediaController extends Controller
{
    public function show(int $id): void
    {
        $model = new MediaModel($this->pdo);
        $media = $model->findById($id);
        if (!$media) { http_response_code(404); echo 'Not found'; return; }
        $this->render('media/show', compact('media'));
    }

    public function play(int $id): void
    {
        $model = new MediaModel($this->pdo);
        $media = $model->findById($id);
        if (!$media) { http_response_code(404); echo 'Not found'; return; }
        $user = auth_user();
        $isPaid = (bool)$media['is_paid'];
        if ($isPaid && (!$user || ($user['subscription_status'] ?? 'none') !== 'active')) {
            $this->render('media/subscribe', compact('media'));
            return;
        }
        if ($user) {
            $stmt = $this->pdo->prepare('INSERT INTO view_history (user_id, content_id, created_at) VALUES (?,?,NOW())');
            $stmt->execute([(int)$user['id'], (int)$media['id']]);
        }
        $this->render('media/play', compact('media'));
    }
}
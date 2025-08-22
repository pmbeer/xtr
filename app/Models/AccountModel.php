<?php
declare(strict_types=1);

namespace App\Models;

use Core\Model;

final class AccountModel extends Model
{
    public function getHistory(int $userId): array
    {
        $sql = 'SELECT h.created_at, c.id, c.title, c.poster_url FROM view_history h JOIN content c ON c.id = h.content_id WHERE h.user_id = ? ORDER BY h.created_at DESC LIMIT 50';
        return $this->fetchAll($sql, [$userId]);
    }

    public function getMyList(int $userId): array
    {
        $sql = 'SELECT c.id, c.title, c.poster_url FROM wishlist w JOIN content c ON c.id = w.content_id WHERE w.user_id = ? ORDER BY w.id DESC LIMIT 50';
        return $this->fetchAll($sql, [$userId]);
    }
}
<?php
declare(strict_types=1);

namespace App\Models;

use Core\Model;

final class ContentModel extends Model
{
    public function getBanners(): array
    {
        return $this->fetchAll('SELECT id, title, subtitle, image_url, link_url FROM banners WHERE is_active = 1 ORDER BY sort_order ASC LIMIT 5');
    }

    public function getFeatured(int $limit = 20): array
    {
        $sql = 'SELECT id, title, poster_url, type, rating FROM content WHERE is_featured = 1 ORDER BY updated_at DESC LIMIT ' . (int)$limit;
        return $this->fetchAll($sql);
    }

    public function getLatestMovies(int $limit = 20): array
    {
        return $this->fetchAll("SELECT id, title, poster_url, year, rating FROM content WHERE type = 'movie' ORDER BY created_at DESC LIMIT " . (int)$limit);
    }

    public function getLatestSeries(int $limit = 20): array
    {
        return $this->fetchAll("SELECT id, title, poster_url, year, rating FROM content WHERE type = 'series' ORDER BY created_at DESC LIMIT " . (int)$limit);
    }

    public function getEditorsChoice(int $limit = 24): array
    {
        return $this->fetchAll('SELECT id, title, poster_url, year, rating FROM content ORDER BY rating DESC LIMIT ' . (int)$limit);
    }

    public function getOriginals(int $limit = 20): array
    {
        return $this->fetchAll('SELECT id, title, poster_url, year, rating FROM content WHERE is_original = 1 ORDER BY rating DESC LIMIT ' . (int)$limit);
    }

    public function getKids(): array
    {
        return $this->fetchAll("SELECT id, title, poster_url, year, rating FROM content WHERE is_kids = 1 ORDER BY created_at DESC LIMIT 24");
    }

    public function getTvChannels(): array
    {
        return $this->fetchAll('SELECT id, name, logo_url, channel_number, current_program, program_end FROM tv_channels WHERE is_active = 1 ORDER BY sort_order ASC LIMIT 100');
    }

    public function getContinueWatching(int $userId): array
    {
        $sql = 'SELECT c.id, c.title, c.poster_url, wp.progress_pct
                FROM watch_progress wp
                JOIN content c ON c.id = wp.content_id
                WHERE wp.user_id = ? AND wp.progress_pct > 0 AND wp.progress_pct < 95
                ORDER BY wp.updated_at DESC LIMIT 12';
        return $this->fetchAll($sql, [$userId]);
    }

    public function listByType(string $type, array $filters = []): array
    {
        $where = ['type = :type'];
        $params = [':type' => $type];
        if (!empty($filters['genre'])) { $where[] = 'genre_id = :genre'; $params[':genre'] = (int)$filters['genre']; }
        if (!empty($filters['tag'])) { $where[] = 'tags LIKE :tag'; $params[':tag'] = '%' . $filters['tag'] . '%'; }
        $sql = 'SELECT id, title, poster_url, year, rating FROM content WHERE ' . implode(' AND ', $where) . ' ORDER BY created_at DESC LIMIT 200';
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    public function listKids(): array
    {
        return $this->getKids();
    }

    public function search(string $q): array
    {
        $like = '%' . $q . '%';
        $sql = 'SELECT id, title, poster_url, year, type, rating FROM content WHERE title LIKE ? OR description LIKE ? ORDER BY rating DESC LIMIT 50';
        return $this->fetchAll($sql, [$like, $like]);
    }
}

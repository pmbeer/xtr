<?php
declare(strict_types=1);

namespace App\Models;

use Core\Model;

final class ContentModel extends Model
{
    public function getBanners(): array
    {
        $sql = 'SELECT id, title, image_url, link_url FROM banners WHERE is_active = 1 ORDER BY sort_order ASC LIMIT 10';
        return $this->fetchAll($sql);
    }

    public function getFeatured(): array
    {
        $sql = 'SELECT id, title, poster_url, type FROM content WHERE is_featured = 1 ORDER BY updated_at DESC LIMIT 20';
        return $this->fetchAll($sql);
    }

    public function getLatestMovies(): array
    {
        $sql = "SELECT id, title, poster_url, year FROM content WHERE type = 'movie' ORDER BY created_at DESC LIMIT 20";
        return $this->fetchAll($sql);
    }

    public function getLatestSeries(): array
    {
        $sql = "SELECT id, title, poster_url, year FROM content WHERE type = 'series' ORDER BY created_at DESC LIMIT 20";
        return $this->fetchAll($sql);
    }

    public function getKids(): array
    {
        $sql = "SELECT id, title, poster_url, year FROM content WHERE is_kids = 1 ORDER BY created_at DESC LIMIT 20";
        return $this->fetchAll($sql);
    }

    public function getTvChannels(): array
    {
        $sql = 'SELECT id, name as title, logo_url as poster_url FROM tv_channels WHERE is_active = 1 ORDER BY sort_order ASC LIMIT 50';
        return $this->fetchAll($sql);
    }

    public function listByType(string $type, array $filters = []): array
    {
        $where = ['type = :type'];
        $params = [':type' => $type];
        if (!empty($filters['genre'])) { $where[] = 'genre_id = :genre'; $params[':genre'] = (int)$filters['genre']; }
        if (!empty($filters['year'])) { $where[] = 'year = :year'; $params[':year'] = (int)$filters['year']; }
        if (!empty($filters['country'])) { $where[] = 'country = :country'; $params[':country'] = $filters['country']; }
        $sql = 'SELECT id, title, poster_url, year FROM content WHERE ' . implode(' AND ', $where) . ' ORDER BY created_at DESC LIMIT 200';
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    public function listKids(): array
    {
        $sql = 'SELECT id, title, poster_url, year FROM content WHERE is_kids = 1 ORDER BY created_at DESC LIMIT 200';
        return $this->fetchAll($sql);
    }
}
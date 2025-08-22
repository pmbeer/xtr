<?php
declare(strict_types=1);

namespace App\Models;

use Core\Model;

final class MediaModel extends Model
{
    public function findById(int $id): ?array
    {
        $sql = 'SELECT c.*, g.name AS genre_name FROM content c LEFT JOIN genres g ON g.id = c.genre_id WHERE c.id = ? LIMIT 1';
        $media = $this->fetch($sql, [$id]);
        if (!$media) return null;
        // sources
        $media['sources'] = $this->fetchAll('SELECT quality, url, mime FROM content_sources WHERE content_id = ? ORDER BY quality DESC', [$id]);
        // images
        $media['images'] = $this->fetchAll('SELECT url FROM content_images WHERE content_id = ? ORDER BY sort_order ASC', [$id]);
        // cast
        $media['cast'] = $this->fetchAll('SELECT name, role FROM content_cast WHERE content_id = ? ORDER BY sort_order ASC', [$id]);
        // seasons and episodes if series
        if ($media['type'] === 'series') {
            $media['seasons'] = $this->fetchAll('SELECT id, season_number, title FROM seasons WHERE content_id = ? ORDER BY season_number ASC', [$id]);
            foreach ($media['seasons'] as &$s) {
                $s['episodes'] = $this->fetchAll('SELECT id, episode_number, title, duration, is_paid FROM episodes WHERE season_id = ? ORDER BY episode_number ASC', [$s['id']]);
            }
        }
        return $media;
    }
}
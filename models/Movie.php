<?php

declare(strict_types=1);

namespace Models;

use Core\Model;
use PDO;

class Movie extends Model
{
	public function getFeatured(): array
	{
		$stmt = $this->db->prepare('SELECT id, title, poster_url, backdrop_url FROM movies WHERE is_featured = 1 ORDER BY updated_at DESC LIMIT 12');
		$stmt->execute();
		return $stmt->fetchAll();
	}

	public function getTrending(): array
	{
		$stmt = $this->db->prepare('SELECT id, title, poster_url FROM movies ORDER BY views_last_7d DESC, updated_at DESC LIMIT 18');
		$stmt->execute();
		return $stmt->fetchAll();
	}

	public function getNewReleases(): array
	{
		$stmt = $this->db->prepare('SELECT id, title, poster_url, release_year FROM movies ORDER BY release_date DESC, id DESC LIMIT 18');
		$stmt->execute();
		return $stmt->fetchAll();
	}
}
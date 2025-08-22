<?php

declare(strict_types=1);

namespace Models;

use Core\Model;
use Core\DB;

final class Movie extends Model
{
	public static function getFeatured(int $limit = 10): array
	{
		$sql = 'SELECT id, title, slug, poster_url, rating FROM movies WHERE is_featured = 1 ORDER BY featured_order ASC, id DESC LIMIT ?';
		$stmt = DB::pdo()->prepare($sql);
		$stmt->bindValue(1, $limit, \PDO::PARAM_INT);
		$stmt->execute();
		return $stmt->fetchAll();
	}

	public static function getTrending(int $limit = 12): array
	{
		$sql = 'SELECT id, title, slug, poster_url, rating FROM movies ORDER BY views_week DESC, id DESC LIMIT ?';
		$stmt = DB::pdo()->prepare($sql);
		$stmt->bindValue(1, $limit, \PDO::PARAM_INT);
		$stmt->execute();
		return $stmt->fetchAll();
	}

	public static function getLatest(int $limit = 12): array
	{
		$sql = 'SELECT id, title, slug, poster_url, rating FROM movies ORDER BY released_at DESC, id DESC LIMIT ?';
		$stmt = DB::pdo()->prepare($sql);
		$stmt->bindValue(1, $limit, \PDO::PARAM_INT);
		$stmt->execute();
		return $stmt->fetchAll();
	}
}
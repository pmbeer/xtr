<?php

declare(strict_types=1);

namespace Core;

abstract class Model
{
	protected static function db(): \PDO
	{
		return DB::pdo();
	}
}
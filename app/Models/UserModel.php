<?php
declare(strict_types=1);

namespace App\Models;

use Core\Model;

final class UserModel extends Model
{
    public function findByEmail(string $email): ?array
    {
        $sql = 'SELECT id, name, email, password_hash, role, subscription_status FROM users WHERE email = ? LIMIT 1';
        return $this->fetch($sql, [$email]);
    }

    public function existsByEmail(string $email): bool
    {
        $sql = 'SELECT 1 FROM users WHERE email = ? LIMIT 1';
        return $this->fetch($sql, [$email]) !== null;
    }

    public function create(string $name, string $email, string $passwordHash): int
    {
        $sql = 'INSERT INTO users (name, email, password_hash, role, subscription_status, created_at) VALUES (?,?,?,?,?,NOW())';
        $this->execute($sql, [$name, $email, $passwordHash, 'user', 'none']);
        return (int)$this->lastInsertId();
    }
}
<?php
declare(strict_types=1);

namespace App\Models;

use Core\Model;

final class AdminModel extends Model
{
    public function getStats(): array
    {
        $users = $this->fetch('SELECT COUNT(*) AS c FROM users') ?? ['c'=>0];
        $content = $this->fetch('SELECT COUNT(*) AS c FROM content') ?? ['c'=>0];
        $views = $this->fetch('SELECT COUNT(*) AS c FROM view_history') ?? ['c'=>0];
        return [
            'users' => (int)$users['c'],
            'content' => (int)$content['c'],
            'views' => (int)$views['c'],
        ];
    }

    public function listContent(): array
    {
        return $this->fetchAll('SELECT id, title, type, year FROM content ORDER BY id DESC LIMIT 200');
    }

    public function getContent(int $id): ?array
    {
        return $this->fetch('SELECT id, type, title, description, year, country, genre_id, is_featured, is_kids, is_paid, poster_url FROM content WHERE id = ?', [$id]);
    }

    public function createContent(array $data): int
    {
        $sql = 'INSERT INTO content (type,title,description,year,country,genre_id,is_featured,is_kids,is_paid,poster_url,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,NOW())';
        $this->execute($sql, [
            $data['type'], $data['title'], $data['description'], $data['year'], $data['country'], $data['genre_id'],
            $data['is_featured'], $data['is_kids'], $data['is_paid'], $data['poster_url']
        ]);
        return (int)$this->lastInsertId();
    }

    public function updateContent(int $id, array $data): void
    {
        $sql = 'UPDATE content SET type=?, title=?, description=?, year=?, country=?, genre_id=?, is_featured=?, is_kids=?, is_paid=?, poster_url=?, updated_at=NOW() WHERE id=?';
        $this->execute($sql, [
            $data['type'], $data['title'], $data['description'], $data['year'], $data['country'], $data['genre_id'],
            $data['is_featured'], $data['is_kids'], $data['is_paid'], $data['poster_url'], $id
        ]);
    }

    public function deleteContent(int $id): void
    {
        $this->execute('DELETE FROM content WHERE id = ?', [$id]);
    }

    public function listUsers(): array
    {
        return $this->fetchAll('SELECT id, name, email, role, subscription_status FROM users ORDER BY id DESC LIMIT 200');
    }

    public function getUser(int $id): ?array
    {
        return $this->fetch('SELECT id, name, email, role, subscription_status FROM users WHERE id = ?', [$id]);
    }

    public function updateUser(int $id, array $data): void
    {
        $this->execute('UPDATE users SET name=?, email=?, role=?, subscription_status=? WHERE id = ?', [
            $data['name'], $data['email'], $data['role'], $data['subscription_status'], $id
        ]);
    }

    public function deleteUser(int $id): void
    {
        $this->execute('DELETE FROM users WHERE id = ?', [$id]);
    }
}
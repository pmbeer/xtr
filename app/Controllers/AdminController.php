<?php
declare(strict_types=1);

namespace App\Controllers;

use Core\Controller;
use App\Models\AdminModel;
use Security;

final class AdminController extends Controller
{
    private function requireAdmin(): void
    {
        $user = auth_user();
        if (!$user || ($user['role'] ?? 'user') !== 'admin') {
            http_response_code(403);
            echo 'Forbidden';
            exit;
        }
    }

    public function index(): void
    {
        $this->requireAdmin();
        $model = new AdminModel($this->pdo);
        $stats = $model->getStats();
        $this->render('admin/index', compact('stats'));
    }

    public function content(): void
    {
        $this->requireAdmin();
        $model = new AdminModel($this->pdo);
        $items = $model->listContent();
        $this->render('admin/content', compact('items'));
    }

    public function contentCreate(): void
    {
        $this->requireAdmin();
        $item = null;
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            if (!Security::verifyCsrfToken($_POST['csrf_token'] ?? '')) { http_response_code(419); echo 'Invalid CSRF'; return; }
            $data = $this->collectContentData();
            $model = new AdminModel($this->pdo);
            $id = $model->createContent($data);
            $this->redirect('/admin/content');
            return;
        }
        $this->render('admin/content_form', compact('item'));
    }

    public function contentEdit(int $id): void
    {
        $this->requireAdmin();
        $model = new AdminModel($this->pdo);
        $item = $model->getContent($id);
        if (!$item) { http_response_code(404); echo 'Not found'; return; }
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            if (!Security::verifyCsrfToken($_POST['csrf_token'] ?? '')) { http_response_code(419); echo 'Invalid CSRF'; return; }
            $data = $this->collectContentData();
            $model->updateContent($id, $data);
            $this->redirect('/admin/content');
            return;
        }
        $this->render('admin/content_form', compact('item'));
    }

    public function contentDelete(int $id): void
    {
        $this->requireAdmin();
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            if (!Security::verifyCsrfToken($_POST['csrf_token'] ?? '')) { http_response_code(419); echo 'Invalid CSRF'; return; }
            $model = new AdminModel($this->pdo);
            $model->deleteContent($id);
            $this->redirect('/admin/content');
            return;
        }
        http_response_code(405);
    }

    private function collectContentData(): array
    {
        return [
            'type' => Security::input('type','movie'),
            'title' => Security::input('title',''),
            'description' => Security::input('description',''),
            'year' => (int)(Security::input('year','0')),
            'country' => Security::input('country',''),
            'genre_id' => (int)(Security::input('genre_id','0')) ?: null,
            'is_featured' => isset($_POST['is_featured']) ? 1 : 0,
            'is_kids' => isset($_POST['is_kids']) ? 1 : 0,
            'is_paid' => isset($_POST['is_paid']) ? 1 : 0,
            'poster_url' => Security::input('poster_url',''),
        ];
    }

    public function users(): void
    {
        $this->requireAdmin();
        $model = new AdminModel($this->pdo);
        $users = $model->listUsers();
        $this->render('admin/users', compact('users'));
    }

    public function userEdit(int $id): void
    {
        $this->requireAdmin();
        $model = new AdminModel($this->pdo);
        $user = $model->getUser($id);
        if (!$user) { http_response_code(404); echo 'Not found'; return; }
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            if (!Security::verifyCsrfToken($_POST['csrf_token'] ?? '')) { http_response_code(419); echo 'Invalid CSRF'; return; }
            $data = [
                'name' => Security::input('name',''),
                'email' => Security::input('email',''),
                'role' => Security::input('role','user'),
                'subscription_status' => Security::input('subscription_status','none'),
            ];
            $model->updateUser($id, $data);
            $this->redirect('/admin/users');
            return;
        }
        $this->render('admin/user_form', compact('user'));
    }

    public function userDelete(int $id): void
    {
        $this->requireAdmin();
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            if (!Security::verifyCsrfToken($_POST['csrf_token'] ?? '')) { http_response_code(419); echo 'Invalid CSRF'; return; }
            $model = new AdminModel($this->pdo);
            $model->deleteUser($id);
            $this->redirect('/admin/users');
            return;
        }
        http_response_code(405);
    }
}
<?php
declare(strict_types=1);

namespace App\Controllers;

use Core\Controller;
use App\Models\UserModel;
use Security;

final class AuthController extends Controller
{
    public function login(): void
    {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $email = Security::input('email', '');
            $password = Security::input('password', '');
            $userModel = new UserModel($this->pdo);
            $user = $userModel->findByEmail($email);
            if ($user && password_verify($password, $user['password_hash'])) {
                $_SESSION['user'] = [
                    'id' => (int)$user['id'],
                    'email' => $user['email'],
                    'name' => $user['name'],
                    'role' => $user['role'],
                    'subscription_status' => $user['subscription_status'],
                ];
                $this->redirect('/');
                return;
            }
            $error = 'Неверный email или пароль';
            $this->render('auth/login', compact('error'));
            return;
        }
        $this->render('auth/login');
    }

    public function register(): void
    {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $name = Security::input('name','');
            $email = Security::input('email','');
            $password = Security::input('password','');
            $userModel = new UserModel($this->pdo);
            if ($userModel->existsByEmail($email)) {
                $error = 'Пользователь с таким email уже существует';
                $this->render('auth/register', compact('error'));
                return;
            }
            $hash = password_hash($password, PASSWORD_DEFAULT);
            $userId = $userModel->create($name, $email, $hash);
            $_SESSION['user'] = [
                'id' => $userId,
                'email' => $email,
                'name' => $name,
                'role' => 'user',
                'subscription_status' => 'none',
            ];
            $this->redirect('/');
            return;
        }
        $this->render('auth/register');
    }

    public function logout(): void
    {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            session_destroy();
            $this->redirect('/');
            return;
        }
        http_response_code(405);
    }

    public function reset(): void
    {
        // Demo stub page, no real mailing in this scaffold
        $message = null;
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $message = 'Если email существует, мы отправили ссылку на сброс.';
        }
        $this->render('auth/reset', compact('message'));
    }
}
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
            $phone = preg_replace('/\D/', '', Security::input('phone', ''));
            if (strlen($phone) >= 10) {
                $userModel = new UserModel($this->pdo);
                $user = $userModel->findByPhone('+7' . substr($phone, -10));
                if ($user) {
                    $this->loginUser($user);
                    $this->redirect('/');
                    return;
                }
                $error = 'Номер не найден. Зарегистрируйтесь или войдите по email.';
            } else {
                $email = Security::input('email', '');
                $password = Security::input('password', '');
                $userModel = new UserModel($this->pdo);
                $user = $userModel->findByEmail($email);
                if ($user && password_verify($password, $user['password_hash'])) {
                    $this->loginUser($user);
                    $this->redirect('/');
                    return;
                }
                $error = 'Неверный email или пароль';
            }
            $mode = Security::input('mode', $_GET['mode'] ?? 'phone');
            $this->render('auth/login', compact('error', 'mode'));
            return;
        }
        $mode = $_GET['mode'] ?? 'phone';
        $this->render('auth/login', compact('mode'));
    }

    public function register(): void
    {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $name = Security::input('name', '');
            $email = Security::input('email', '');
            $password = Security::input('password', '');
            $userModel = new UserModel($this->pdo);
            if ($userModel->existsByEmail($email)) {
                $error = 'Пользователь с таким email уже существует';
                $this->render('auth/register', compact('error'));
                return;
            }
            $hash = password_hash($password, PASSWORD_DEFAULT);
            $userId = $userModel->create($name, $email, $hash);
            $_SESSION['user'] = ['id' => $userId, 'email' => $email, 'name' => $name, 'role' => 'user', 'subscription_status' => 'none'];
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
        $message = $_SERVER['REQUEST_METHOD'] === 'POST' ? 'Если email существует, мы отправили ссылку на сброс.' : null;
        $this->render('auth/reset', compact('message'));
    }

    private function loginUser(array $user): void
    {
        $_SESSION['user'] = [
            'id' => (int)$user['id'],
            'email' => $user['email'],
            'name' => $user['name'],
            'role' => $user['role'],
            'subscription_status' => $user['subscription_status'],
        ];
    }
}

<?php
declare(strict_types=1);

namespace App\Controllers;

use Core\Controller;
use App\Models\AccountModel;

final class AccountController extends Controller
{
    public function index(): void
    {
        require_auth();
        $model = new AccountModel($this->pdo);
        $user = auth_user();
        $history = $model->getHistory((int)$user['id']);
        $mylist = $model->getMyList((int)$user['id']);
        $this->render('account/index', compact('user','history','mylist'));
    }
}
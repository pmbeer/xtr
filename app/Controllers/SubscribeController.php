<?php
declare(strict_types=1);

namespace App\Controllers;

use Core\Controller;
use App\Models\SubscribeModel;

final class SubscribeController extends Controller
{
    public function index(): void
    {
        $model = new SubscribeModel($this->pdo);
        $plans = $model->getPlans();
        $this->render('subscribe/index', compact('plans'));
    }

    public function checkout(int $planId): void
    {
        require_auth();
        $model = new SubscribeModel($this->pdo);
        $plan = $model->getPlan($planId);
        if (!$plan) { http_response_code(404); echo 'Тариф не найден'; return; }
        $user = auth_user();
        $model->activate((int)$user['id'], $planId);
        $_SESSION['user']['subscription_status'] = 'active';
        $this->render('subscribe/success', compact('plan'));
    }
}

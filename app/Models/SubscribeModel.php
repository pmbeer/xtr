<?php
declare(strict_types=1);

namespace App\Models;

use Core\Model;

final class SubscribeModel extends Model
{
    public function getPlans(): array
    {
        return $this->fetchAll('SELECT id, name, price, period_days FROM subscription_plans WHERE is_active = 1 ORDER BY sort_order ASC');
    }

    public function getPlan(int $id): ?array
    {
        return $this->fetch('SELECT id, name, price, period_days FROM subscription_plans WHERE id = ? AND is_active = 1', [$id]);
    }

    public function activate(int $userId, int $planId): void
    {
        $plan = $this->getPlan($planId);
        if (!$plan) return;
        $this->execute('INSERT INTO subscriptions (user_id, plan_id, started_at, expires_at, status) VALUES (?,?,NOW(), DATE_ADD(NOW(), INTERVAL ? DAY), "active")', [$userId, $planId, (int)$plan['period_days']]);
        $this->execute('UPDATE users SET subscription_status = "active" WHERE id = ?', [$userId]);
    }
}
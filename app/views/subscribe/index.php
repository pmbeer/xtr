<?php /** @var array $plans */ ?>
<h1>Подписка</h1>
<div class="plans">
  <?php foreach ($plans as $p): ?>
    <div class="plan">
      <h3><?= e($p['name']) ?></h3>
      <div class="price"><?= e(number_format((float)$p['price'], 2, '.', ' ')) ?> ₽ / <?= e($p['period_days']) ?> дн.</div>
      <a class="btn" href="<?= e(url('/subscribe/checkout/' . $p['id'])) ?>">Оформить</a>
    </div>
  <?php endforeach; ?>
</div>
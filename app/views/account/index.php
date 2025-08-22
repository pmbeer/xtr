<?php /** @var array $user,$history,$mylist */ ?>
<h1>Мой Wink</h1>
<section>
  <h3>Профиль</h3>
  <div>Email: <?= e($user['email']) ?> | Подписка: <?= e($user['subscription_status'] ?? 'none') ?></div>
</section>
<section class="carousel">
  <h3>Мой список</h3>
  <div class="cards" data-carousel>
    <?php foreach ($mylist as $c): ?>
      <a class="card" href="<?= e(url('/media/' . $c['id'])) ?>">
        <img src="<?= e($c['poster_url']) ?>" alt="<?= e($c['title']) ?>">
        <div class="card-title"><?= e($c['title']) ?></div>
      </a>
    <?php endforeach; ?>
  </div>
</section>
<section class="carousel">
  <h3>История просмотров</h3>
  <div class="cards" data-carousel>
    <?php foreach ($history as $c): ?>
      <a class="card" href="<?= e(url('/media/' . $c['id'])) ?>">
        <img src="<?= e($c['poster_url']) ?>" alt="<?= e($c['title']) ?>">
        <div class="card-title"><?= e($c['title']) ?></div>
      </a>
    <?php endforeach; ?>
  </div>
</section>
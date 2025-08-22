<?php /** @var array $items */ ?>
<h1>ТВ-каналы</h1>
<div class="cards cards-tv" data-carousel>
  <?php foreach ($items as $c): ?>
    <div class="card card-tv">
      <img src="<?= e($c['poster_url']) ?>" alt="<?= e($c['title']) ?>">
      <div class="card-title"><?= e($c['title']) ?></div>
    </div>
  <?php endforeach; ?>
</div>
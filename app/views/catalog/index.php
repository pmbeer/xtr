<?php /** @var string $title */ /** @var array $items */ ?>
<h1><?= e($title) ?></h1>
<div class="cards" data-carousel>
  <?php foreach ($items as $c): ?>
    <a class="card" href="<?= e(url('/media/' . $c['id'])) ?>">
      <img src="<?= e($c['poster_url']) ?>" alt="<?= e($c['title']) ?>">
      <div class="card-title"><?= e($c['title']) ?> (<?= e((string)$c['year']) ?>)</div>
    </a>
  <?php endforeach; ?>
</div>
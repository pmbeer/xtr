<?php /** @var array $media */ ?>
<article class="media">
  <div class="media-hero">
    <img class="poster" src="<?= e($media['poster_url']) ?>" alt="<?= e($media['title']) ?>">
    <div class="meta">
      <h1><?= e($media['title']) ?></h1>
      <div class="subline"><?= e($media['year']) ?> • <?= e($media['country'] ?? '') ?> • <?= e($media['genre_name'] ?? '') ?></div>
      <p class="overview"><?= e($media['description']) ?></p>
      <a class="btn" href="<?= e(url('/media/play/' . $media['id'])) ?>">Смотреть</a>
    </div>
  </div>

  <?php if (!empty($media['images'])): ?>
  <section class="gallery">
    <h3>Кадры</h3>
    <div class="cards" data-carousel>
      <?php foreach ($media['images'] as $img): ?>
        <img class="shot" src="<?= e($img['url']) ?>" alt="shot">
      <?php endforeach; ?>
    </div>
  </section>
  <?php endif; ?>

  <?php if (!empty($media['cast'])): ?>
  <section class="cast">
    <h3>Актеры</h3>
    <div class="cards" data-carousel>
      <?php foreach ($media['cast'] as $c): ?>
        <div class="card">
          <div class="card-title"><?= e($c['name']) ?> — <?= e($c['role']) ?></div>
        </div>
      <?php endforeach; ?>
    </div>
  </section>
  <?php endif; ?>

  <?php if ($media['type'] === 'series' && !empty($media['seasons'])): ?>
  <section class="seasons">
    <h3>Сезоны и серии</h3>
    <?php foreach ($media['seasons'] as $s): ?>
      <h4>Сезон <?= e((string)$s['season_number']) ?> — <?= e($s['title']) ?></h4>
      <ul class="episodes">
        <?php foreach ($s['episodes'] as $ep): ?>
          <li>
            <a href="<?= e(url('/media/play/' . $media['id'] . '?episode=' . $ep['id'])) ?>">Серия <?= e((string)$ep['episode_number']) ?> — <?= e($ep['title']) ?></a>
            <?php if ($ep['is_paid']): ?><span class="badge">Подписка</span><?php endif; ?>
          </li>
        <?php endforeach; ?>
      </ul>
    <?php endforeach; ?>
  </section>
  <?php endif; ?>
</article>
<?php /** @var array $banners,$featured,$movies,$series,$kids,$tv */ ?>
<section class="banners">
  <div class="banner-slider" data-slider>
    <?php foreach ($banners as $b): ?>
      <a class="banner-slide" href="<?= e($b['link_url']) ?>" style="background-image:url('<?= e($b['image_url']) ?>')">
        <div class="banner-caption">
          <h2><?= e($b['title']) ?></h2>
        </div>
      </a>
    <?php endforeach; ?>
  </div>
</section>

<section class="carousel">
  <h3>Избранное</h3>
  <div class="cards" data-carousel>
    <?php foreach ($featured as $c): ?>
      <a class="card" href="<?= e(url('/media/' . $c['id'])) ?>">
        <img src="<?= e($c['poster_url']) ?>" alt="<?= e($c['title']) ?>">
        <div class="card-title"><?= e($c['title']) ?></div>
      </a>
    <?php endforeach; ?>
  </div>
</section>

<section class="carousel">
  <h3>Фильмы</h3>
  <div class="cards" data-carousel>
    <?php foreach ($movies as $c): ?>
      <a class="card" href="<?= e(url('/media/' . $c['id'])) ?>">
        <img src="<?= e($c['poster_url']) ?>" alt="<?= e($c['title']) ?>">
        <div class="card-title"><?= e($c['title']) ?></div>
      </a>
    <?php endforeach; ?>
  </div>
</section>

<section class="carousel">
  <h3>Сериалы</h3>
  <div class="cards" data-carousel>
    <?php foreach ($series as $c): ?>
      <a class="card" href="<?= e(url('/media/' . $c['id'])) ?>">
        <img src="<?= e($c['poster_url']) ?>" alt="<?= e($c['title']) ?>">
        <div class="card-title"><?= e($c['title']) ?></div>
      </a>
    <?php endforeach; ?>
  </div>
</section>

<section class="carousel">
  <h3>Детям</h3>
  <div class="cards" data-carousel>
    <?php foreach ($kids as $c): ?>
      <a class="card" href="<?= e(url('/media/' . $c['id'])) ?>">
        <img src="<?= e($c['poster_url']) ?>" alt="<?= e($c['title']) ?>">
        <div class="card-title"><?= e($c['title']) ?></div>
      </a>
    <?php endforeach; ?>
  </div>
</section>

<section class="carousel">
  <h3>ТВ-каналы</h3>
  <div class="cards cards-tv" data-carousel>
    <?php foreach ($tv as $c): ?>
      <a class="card card-tv" href="#">
        <img src="<?= e($c['poster_url']) ?>" alt="<?= e($c['title']) ?>">
        <div class="card-title"><?= e($c['title']) ?></div>
      </a>
    <?php endforeach; ?>
  </div>
</section>
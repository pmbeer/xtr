<?php
use Core\Security;
?>
<section class="hero">
	<div class="container">
		<div class="carousel" data-carousel>
			<?php foreach ($featured as $item): ?>
				<a class="carousel__item" href="/movie?id=<?= (int)$item['id'] ?>">
					<img src="<?= Security::e($item['backdrop_url'] ?: $item['poster_url']) ?>" alt="<?= Security::e($item['title']) ?>">
					<div class="carousel__caption"><?= Security::e($item['title']) ?></div>
				</a>
			<?php endforeach; ?>
		</div>
	</div>
</section>
<section class="section">
	<div class="container">
		<h2 class="section__title">В тренде</h2>
		<div class="grid">
			<?php foreach ($trending as $item): ?>
				<a class="card" href="/movie?id=<?= (int)$item['id'] ?>">
					<img class="card__poster" src="<?= Security::e($item['poster_url']) ?>" alt="<?= Security::e($item['title']) ?>">
					<div class="card__title"><?= Security::e($item['title']) ?></div>
				</a>
			<?php endforeach; ?>
		</div>
	</div>
</section>
<section class="section">
	<div class="container">
		<h2 class="section__title">Новинки</h2>
		<div class="grid">
			<?php foreach ($newReleases as $item): ?>
				<a class="card" href="/movie?id=<?= (int)$item['id'] ?>">
					<img class="card__poster" src="<?= Security::e($item['poster_url']) ?>" alt="<?= Security::e($item['title']) ?>">
					<div class="card__title"><?= Security::e($item['title']) ?></div>
				</a>
			<?php endforeach; ?>
		</div>
	</div>
</section>
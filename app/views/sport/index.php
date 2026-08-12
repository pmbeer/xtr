<?php /** @var array $live,$featured */ $pageTitle = 'Спорт — Wink'; $showPromo = false; ?>
<div class="container">
	<header class="category-page__header">
		<h1 class="category-page__title">Спорт</h1>
		<p class="category-page__desc">Прямые трансляции и спортивные события на Wink</p>
	</header>
	<?php if (!empty($featured)): ?>
	<section class="row-section">
		<div class="row-section__head"><h2 class="row-section__title">Главные спортивные события недели</h2></div>
		<div class="row-scroll" data-scroll-row>
			<?php foreach ($featured as $c): ?>
			<article class="poster-card">
				<a class="poster-card__link" href="<?= e(url('/media/' . $c['id'])) ?>">
					<div class="poster-card__img"><img src="<?= e($c['poster_url']) ?>" alt="<?= e($c['title']) ?>"></div>
					<h3 class="poster-card__title"><?= e($c['title']) ?></h3>
				</a>
			</article>
			<?php endforeach; ?>
		</div>
	</section>
	<?php endif; ?>
</div>

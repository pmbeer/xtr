<?php /** @var string $title */ /** @var array $items */ $pageTitle = ($title ?? 'Каталог') . ' — Wink'; $showPromo = false; ?>
<div class="container">
	<header class="category-page__header">
		<h1 class="category-page__title"><?= e($title ?? 'Каталог') ?></h1>
	</header>
	<div class="grid grid--catalog">
		<?php foreach ($items as $c): ?>
		<article class="poster-card">
			<a class="poster-card__link" href="<?= e(url('/media/' . $c['id'])) ?>">
				<div class="poster-card__img">
					<img src="<?= e($c['poster_url']) ?>" alt="<?= e($c['title']) ?>" loading="lazy">
					<div class="poster-card__overlay"><span class="poster-card__play"><svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg></span></div>
					<?php if (!empty($c['rating'])): ?><span class="poster-card__badge">★ <?= e((string)$c['rating']) ?></span><?php endif; ?>
				</div>
				<h3 class="poster-card__title"><?= e($c['title']) ?></h3>
			</a>
		</article>
		<?php endforeach; ?>
	</div>
</div>

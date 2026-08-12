<?php /** @var array $c */ ?>
<article class="poster-card">
	<a class="poster-card__link" href="<?= e(url('/media/' . $c['id'])) ?>">
		<div class="poster-card__img">
			<img src="<?= e($c['poster_url']) ?>" alt="<?= e($c['title']) ?>" loading="lazy">
			<div class="poster-card__overlay"><span class="poster-card__play"><svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg></span></div>
		</div>
		<h3 class="poster-card__title"><?= e($c['title']) ?></h3>
	</a>
</article>

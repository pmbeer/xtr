<?php /** @var array $media */ $pageTitle = e($media['title']) . ' — Wink'; $showPromo = false; ?>
<article class="movie-page">
	<div class="movie-page__hero">
		<div class="movie-page__backdrop">
			<img src="<?= e($media['backdrop_url'] ?? $media['poster_url']) ?>" alt="">
		</div>
		<div class="movie-page__hero-fade"></div>
		<div class="container movie-page__hero-inner">
			<figure class="movie-page__poster">
				<img src="<?= e($media['poster_url']) ?>" alt="<?= e($media['title']) ?>">
			</figure>
			<div class="movie-page__info">
				<h1 class="movie-page__title"><?= e($media['title']) ?></h1>
				<div class="movie-page__meta-line">
					<?php if ($media['rating']): ?><span class="movie-page__rating"><?= e((string)$media['rating']) ?></span><span>·</span><?php endif; ?>
					<span><?= e((string)$media['year']) ?></span>
					<?php if ($media['genre_name']): ?><span>· <?= e($media['genre_name']) ?></span><?php endif; ?>
				</div>
				<div class="movie-page__chips">
					<?php if ($media['duration_minutes']): ?><span class="chip"><?= (int)$media['duration_minutes'] ?> мин</span><?php endif; ?>
					<span class="chip"><?= e($media['age_rating'] ?? '16+') ?></span>
					<?php if ($media['is_paid']): ?><span class="chip">В подписке</span><?php endif; ?>
				</div>
				<div class="movie-page__actions">
					<a href="<?= e(url('/media/play/' . $media['id'])) ?>" class="btn btn--primary btn--lg">
						<?= $media['type'] === 'series' ? 'Смотреть сериал' : 'Смотреть фильм' ?>
					</a>
				</div>
				<div class="movie-page__secondary">
					<button type="button" class="action-btn" data-share-open>Поделиться</button>
					<button type="button" class="action-btn">Загрузить на устройство</button>
				</div>
			</div>
		</div>
	</div>

	<div class="container movie-page__body">
		<section class="movie-page__section">
			<h2 class="movie-page__section-title"><?= $media['type'] === 'series' ? 'О сериале' : 'О фильме' ?></h2>
			<div class="movie-page__text"><?= e($media['description']) ?></div>
		</section>

		<section class="movie-page__meta-grid">
			<div class="meta-item"><span class="meta-item__label">Страна</span><span class="meta-item__value"><?= e($media['country'] ?? '—') ?></span></div>
			<div class="meta-item"><span class="meta-item__label">Жанр</span><span class="meta-item__value"><?= e($media['genre_name'] ?? '—') ?></span></div>
			<div class="meta-item"><span class="meta-item__label">Качество</span><span class="meta-item__value">Full HD</span></div>
			<div class="meta-item"><span class="meta-item__label">Время</span><span class="meta-item__value"><?= $media['duration_minutes'] ? (int)$media['duration_minutes'] . ' мин' : '—' ?></span></div>
		</section>

		<section class="movie-page__section">
			<h2 class="movie-page__section-title">Рейтинг</h2>
			<div class="rating-block">
				<div class="rating-block__main">
					<span class="rating-block__score"><?= e((string)$media['rating']) ?></span>
					<span class="rating-block__label">Оценка пользователей Wink</span>
				</div>
				<?php if ($media['kinopoisk_rating']): ?><div class="rating-block__ext"><strong><?= e((string)$media['kinopoisk_rating']) ?></strong> КиноПоиск</div><?php endif; ?>
				<?php if ($media['imdb_rating']): ?><div class="rating-block__ext"><strong><?= e((string)$media['imdb_rating']) ?></strong> IMDb</div><?php endif; ?>
			</div>
		</section>

		<?php if (!empty($media['cast'])): ?>
		<section class="movie-page__section">
			<h2 class="movie-page__section-title">Актёры и съёмочная группа</h2>
			<div class="row-scroll" data-scroll-row>
				<?php foreach ($media['cast'] as $c): ?>
				<div class="cast-card"><div class="cast-card__name"><?= e($c['name']) ?></div><div class="cast-card__role"><?= e($c['role']) ?></div></div>
				<?php endforeach; ?>
			</div>
		</section>
		<?php endif; ?>

		<?php if ($media['type'] === 'series' && !empty($media['seasons'])): ?>
		<section class="seasons" id="episodes">
			<h2 class="movie-page__section-title">Сезоны и серии</h2>
			<?php foreach ($media['seasons'] as $s): ?>
			<h3 class="seasons__heading">Сезон <?= (int)$s['season_number'] ?> — <?= e($s['title']) ?></h3>
			<div class="episodes-grid">
				<?php foreach ($s['episodes'] as $ep): ?>
				<a class="episode-card" href="<?= e(url('/media/play/' . $media['id'] . '?episode=' . $ep['id'])) ?>">
					<div class="episode-card__thumb"><span class="episode-card__play"><svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg></span></div>
					<span class="episode-card__label">Серия <?= (int)$ep['episode_number'] ?> — <?= e($ep['title']) ?></span>
				</a>
				<?php endforeach; ?>
			</div>
			<?php endforeach; ?>
		</section>
		<?php endif; ?>
	</div>
</article>

<div class="modal" id="shareModal" hidden>
	<div class="modal__backdrop" data-modal-close></div>
	<div class="modal__dialog">
		<h3 class="modal__title">Поделиться</h3>
		<input type="text" class="modal__input" value="<?= e(url('/media/' . $media['id'])) ?>" readonly id="shareLink">
		<button type="button" class="btn btn--primary btn--block" data-copy-link>Скопировать ссылку</button>
	</div>
</div>

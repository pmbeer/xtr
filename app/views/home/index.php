<?php
/** @var array $banners,$newReleases,$editorsChoice,$stsTnt,$originals,$continueWatching */
$pageTitle = 'Wink — ТВ-каналы, фильмы и сериалы';
$showPromo = true;
?>
<?php if (!empty($banners)): ?>
<section class="hero" id="hero">
	<div class="hero__slider" id="heroSlider">
		<?php foreach ($banners as $i => $b): ?>
		<div class="hero-slide<?= $i === 0 ? ' active' : '' ?>">
			<div class="hero-slide__bg" style="background-image:url('<?= e($b['image_url']) ?>')"></div>
			<div class="container hero-slide__content">
				<div class="hero-slide__info">
					<span class="hero-slide__badge">Смотрите в подписке</span>
					<h1 class="hero-slide__title"><?= e($b['title']) ?></h1>
					<?php if (!empty($b['subtitle'])): ?><p class="hero-slide__desc"><?= e($b['subtitle']) ?></p><?php endif; ?>
					<div class="hero-slide__actions">
						<a href="<?= e($b['link_url']) ?>" class="btn btn--primary btn--lg">Смотреть</a>
						<a href="<?= e(url('/subscribe')) ?>" class="btn btn--secondary btn--lg">Подключить подписку</a>
					</div>
					<p class="hero-slide__legal">Отключить можно в любой момент в Личном кабинете</p>
				</div>
			</div>
		</div>
		<?php endforeach; ?>
	</div>
	<div class="hero__fade"></div>
	<div class="hero__dots" id="heroDots"></div>
</section>
<?php endif; ?>

<div class="content-rows">
	<?php if (!empty($continueWatching)): ?>
	<section class="row-section row-section--continue">
		<div class="row-section__head container">
			<h2 class="row-section__title">Продолжить просмотр</h2>
		</div>
		<div class="row-scroll row-scroll--wide container" data-scroll-row>
			<?php foreach ($continueWatching as $item): ?>
			<article class="continue-card">
				<a class="continue-card__link" href="<?= e(url('/media/play/' . $item['id'])) ?>">
					<div class="continue-card__thumb">
						<img src="<?= e($item['poster_url']) ?>" alt="<?= e($item['title']) ?>" loading="lazy">
						<div class="continue-card__overlay"><span class="continue-card__play"><svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg></span></div>
						<div class="continue-card__progress" style="width:<?= (int)($item['progress_pct'] ?? 35) ?>%"></div>
					</div>
					<h3 class="continue-card__title"><?= e($item['title']) ?></h3>
				</a>
			</article>
			<?php endforeach; ?>
		</div>
	</section>
	<?php endif; ?>

	<?php
	$rows = [
		['title' => 'Новинки', 'items' => $newReleases ?? []],
		['title' => 'Выбор зрителей', 'items' => $editorsChoice ?? []],
		['title' => 'Любимки СТС и ТНТ на Wink', 'subtitle' => 'Ждать эфира не нужно: смотрите сериалы и шоу телеканалов в любое время', 'items' => $stsTnt ?? []],
		['title' => 'Wink Originals', 'subtitle' => 'Лучшие сериалы из линейки оригинальных проектов Wink', 'items' => $originals ?? []],
	];
	foreach ($rows as $row):
		if (empty($row['items'])) continue;
	?>
	<section class="row-section">
		<div class="row-section__head container">
			<h2 class="row-section__title"><?= e($row['title']) ?></h2>
			<?php if (!empty($row['subtitle'])): ?><p class="row-section__subtitle"><?= e($row['subtitle']) ?></p><?php endif; ?>
		</div>
		<div class="row-scroll container" data-scroll-row>
			<?php foreach ($row['items'] as $c): ?>
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
	</section>
	<?php endforeach; ?>
</div>

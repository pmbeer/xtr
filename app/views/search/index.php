<?php /** @var string $q, array $items, $newReleases, $topSeries */ $pageTitle = 'Поиск — Wink'; $showPromo = false; ?>
<div class="container page-search">
	<h1 class="page-header__title">Поиск</h1>
	<?php if ($q === ''): ?>
	<p class="row-section__subtitle">Введите запрос в строку поиска в шапке сайта</p>
	<?php if (!empty($newReleases)): ?>
	<section class="row-section">
		<div class="row-section__head"><h2 class="row-section__title">Новинки</h2></div>
		<div class="row-scroll" data-scroll-row>
			<?php foreach ($newReleases as $c): include __DIR__ . '/../partials/poster-card.php'; endforeach; ?>
		</div>
	</section>
	<?php endif; ?>
	<?php else: ?>
	<p class="row-section__subtitle">Результаты по запросу «<?= e($q) ?>»</p>
	<div class="grid grid--catalog">
		<?php foreach ($items as $c): include __DIR__ . '/../partials/poster-card.php'; endforeach; ?>
	</div>
	<?php if (empty($items)): ?><p style="margin-top:24px;color:rgba(255,255,255,0.5)">Ничего не найдено</p><?php endif; ?>
	<?php endif; ?>
</div>

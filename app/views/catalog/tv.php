<?php /** @var array $items */ $pageTitle = 'ТВ-каналы — Wink'; $showPromo = false; ?>
<div class="container page-tv">
	<header class="page-header">
		<h1 class="page-header__title">ТВ-каналы</h1>
		<div class="page-header__controls">
			<button type="button" class="btn btn--ghost btn--sm">Фильтр</button>
			<button type="button" class="btn btn--ghost btn--sm">Сортировка: По номеру</button>
		</div>
	</header>
	<div class="channel-list">
		<?php foreach ($items as $ch): ?>
		<article class="channel-row">
			<a class="channel-row__link" href="<?= e(url('/tv/watch/' . $ch['id'])) ?>">
				<span class="channel-row__age">16+</span>
				<span class="channel-row__time"><?= $ch['program_end'] ? 'ещё 43 мин · ' : '' ?><?= date('H:i') ?></span>
				<span class="channel-row__program"><?= e($ch['current_program'] ?? 'Прямой эфир') ?></span>
				<span class="channel-row__name"><?= e($ch['name']) ?></span>
				<span class="channel-row__num"><?= e($ch['channel_number'] ?? '') ?></span>
			</a>
		</article>
		<?php endforeach; ?>
	</div>
</div>

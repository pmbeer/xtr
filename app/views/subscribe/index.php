<?php /** @var array $plans */ $pageTitle = 'Подписки — Wink'; $showPromo = false; ?>
<div class="container page-services">
	<h1 class="page-header__title">Подписки</h1>
	<div class="tabs" data-tabs>
		<button type="button" class="tabs__btn active">Все подписки</button>
		<button type="button" class="tabs__btn">Со скидкой</button>
		<button type="button" class="tabs__btn">Сервисы</button>
	</div>
	<div class="plans-grid">
		<?php foreach ($plans as $p): ?>
		<div class="plan-card">
			<h3 class="plan-card__name"><?= e($p['name']) ?></h3>
			<?php if (!empty($p['badge'])): ?><span class="plan-card__badge"><?= e($p['badge']) ?></span><?php endif; ?>
			<div class="plan-card__stats">
				<span class="plan-card__stat"><strong><?= (int)($p['tv_channels'] ?? 241) ?></strong> ТВ-каналов</span>
				<span class="plan-card__stat"><strong><?= number_format((int)($p['titles_count'] ?? 50000), 0, '', ' ') ?></strong> фильмов и сериалов</span>
			</div>
			<?php if (!empty($p['description'])): ?><p class="plan-card__desc"><?= e($p['description']) ?></p><?php endif; ?>
			<a href="<?= e(url('/subscribe/checkout/' . $p['id'])) ?>" class="btn btn--primary btn--block">
				<?php if ((int)($p['trial_days'] ?? 0) > 0): ?>
					Попробовать бесплатно <?= (int)$p['trial_days'] ?> дн., далее — <?= number_format((float)$p['price'], 0, '', ' ') ?> ₽/мес
				<?php else: ?>
					Оформить за <?= number_format((float)$p['price'], 0, '', ' ') ?> ₽
				<?php endif; ?>
			</a>
		</div>
		<?php endforeach; ?>
	</div>
</div>

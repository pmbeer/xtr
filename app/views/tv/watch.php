<?php /** @var array $channel */ $pageTitle = e($channel['name']) . ' — Wink'; $showPromo = false; ?>
<div class="container movie-page__body">
	<h1 class="page-header__title"><?= e($channel['name']) ?></h1>
	<div class="movie-page__player">
		<div class="player">
			<div class="player__screen" style="aspect-ratio:16/9;background:#000;display:flex;align-items:center;justify-content:center;color:rgba(255,255,255,0.5)">
				<div style="text-align:center">
					<div style="width:64px;height:64px;border-radius:50%;background:#FF5A24;display:inline-flex;align-items:center;justify-content:center;margin-bottom:12px">▶</div>
					<p>Прямой эфир: <?= e($channel['current_program'] ?? 'Программа') ?></p>
					<p style="font-size:13px;margin-top:8px">Для просмотра ТВ-каналов необходима активная подписка</p>
					<a href="<?= e(url('/subscribe')) ?>" class="btn btn--primary" style="margin-top:16px">Подключить подписку</a>
				</div>
			</div>
		</div>
	</div>
</div>

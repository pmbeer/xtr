<?php $pageTitle = 'Мой Wink — Личный кабинет'; $showPromo = false; ?>
<div class="account-page">
	<div class="container">
		<header class="account-page__head">
			<h1 class="account-page__title">Мой Wink</h1>
			<p class="account-page__subtitle">Профиль, подписка и ваши списки</p>
		</header>

		<section class="account-card">
			<h2 class="account-card__title">Профиль</h2>
			<dl class="account-card__grid">
				<div class="account-card__row">
					<dt>Имя</dt>
					<dd><?= e($user['name'] ?? 'Пользователь') ?></dd>
				</div>
				<div class="account-card__row">
					<dt>Email</dt>
					<dd><?= e($user['email'] ?? '—') ?></dd>
				</div>
				<div class="account-card__row">
					<dt>Подписка</dt>
					<dd>
						<?php if (($user['subscription_status'] ?? 'none') === 'active'): ?>
							<span class="chip chip--accent">Активна</span>
						<?php else: ?>
							<span class="chip">Не подключена</span>
							<a href="<?= e(url('/subscribe')) ?>" class="account-card__link">Подключить</a>
						<?php endif; ?>
					</dd>
				</div>
			</dl>
		</section>

		<section class="row-section">
			<div class="row-section__head">
				<h2 class="row-section__title">Мой список</h2>
			</div>
			<?php if (empty($mylist)): ?>
				<p class="account-empty">Список пуст. Добавляйте фильмы и сериалы со страницы просмотра.</p>
			<?php else: ?>
			<div class="row-scroll" data-scroll-row>
				<?php foreach ($mylist as $c): ?>
				<article class="poster-card">
					<a class="poster-card__link" href="<?= e(url('/media/' . $c['id'])) ?>">
						<div class="poster-card__img">
							<img src="<?= e($c['poster_url']) ?>" alt="<?= e($c['title']) ?>" loading="lazy">
						</div>
						<h3 class="poster-card__title"><?= e($c['title']) ?></h3>
					</a>
				</article>
				<?php endforeach; ?>
			</div>
			<?php endif; ?>
		</section>

		<section class="row-section">
			<div class="row-section__head">
				<h2 class="row-section__title">История просмотров</h2>
			</div>
			<?php if (empty($history)): ?>
				<p class="account-empty">Вы ещё ничего не смотрели.</p>
			<?php else: ?>
			<div class="row-scroll" data-scroll-row>
				<?php foreach ($history as $c): ?>
				<article class="poster-card">
					<a class="poster-card__link" href="<?= e(url('/media/' . $c['id'])) ?>">
						<div class="poster-card__img">
							<img src="<?= e($c['poster_url']) ?>" alt="<?= e($c['title']) ?>" loading="lazy">
						</div>
						<h3 class="poster-card__title"><?= e($c['title']) ?></h3>
					</a>
				</article>
				<?php endforeach; ?>
			</div>
			<?php endif; ?>
		</section>
	</div>
</div>

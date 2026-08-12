<?php $user = auth_user(); $path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/'; ?>
<header class="header" id="header">
	<div class="container header__inner">
		<div class="header__left">
			<button class="burger" id="burger" type="button" aria-label="Меню"><span></span><span></span><span></span></button>
			<a href="<?= e(url('/')) ?>" class="logo"><span class="logo__mark"></span><span class="logo__word">WINK</span></a>
			<nav class="nav" id="nav">
				<ul class="nav__list">
					<li><a href="<?= e(url('/')) ?>" class="nav__link<?= $path === '/' || str_ends_with($path, '/index.php') ? ' nav__link--active' : '' ?>">Главная</a></li>
					<li><a href="<?= e(url('/tv')) ?>" class="nav__link<?= str_contains($path, '/tv') ? ' nav__link--active' : '' ?>">ТВ-каналы</a></li>
					<li><a href="<?= e(url('/movies')) ?>" class="nav__link<?= str_contains($path, '/movies') ? ' nav__link--active' : '' ?>">Фильмы</a></li>
					<li><a href="<?= e(url('/series')) ?>" class="nav__link<?= str_contains($path, '/series') ? ' nav__link--active' : '' ?>">Сериалы</a></li>
					<li><a href="<?= e(url('/kids')) ?>" class="nav__link<?= str_contains($path, '/kids') ? ' nav__link--active' : '' ?>">Детям</a></li>
					<li><a href="<?= e(url('/sport')) ?>" class="nav__link<?= str_contains($path, '/sport') ? ' nav__link--active' : '' ?>">Спорт</a></li>
					<li><a href="<?= e(url('/subscribe')) ?>" class="nav__link<?= str_contains($path, '/subscribe') ? ' nav__link--active' : '' ?>">Подписки</a></li>
				</ul>
			</nav>
		</div>
		<div class="header__right">
			<form action="<?= e(url('/search')) ?>" method="get" class="search" id="searchForm">
				<button type="button" class="search__icon-btn" id="searchToggle" aria-label="Поиск">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
				</button>
				<input type="text" name="q" id="searchInput" placeholder="Поиск" class="search__input" value="<?= e($_GET['q'] ?? '') ?>">
			</form>
			<div class="auth">
				<?php if ($user): ?>
					<a href="<?= e(url('/account')) ?>" class="auth__profile" title="<?= e($user['name']) ?>">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
					</a>
					<form action="<?= e(url('/auth/logout')) ?>" method="post" class="inline-form">
						<input type="hidden" name="csrf_token" value="<?= e(Security::csrfToken()) ?>">
						<button type="submit" class="auth__link auth__link--btn">Выйти</button>
					</form>
				<?php else: ?>
					<a href="<?= e(url('/auth/login')) ?>" class="auth__link">Вход</a>
					<span class="auth__sep">|</span>
					<a href="<?= e(url('/auth/register')) ?>" class="auth__link">Регистрация</a>
				<?php endif; ?>
			</div>
		</div>
	</div>
</header>

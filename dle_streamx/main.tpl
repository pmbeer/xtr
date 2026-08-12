<!DOCTYPE html>
<html lang="ru">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>{title}</title>
	<meta name="description" content="{meta_description}">
	<meta name="keywords" content="{meta_keywords}">
	<link rel="preconnect" href="https://fonts.googleapis.com">
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
	<link href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">
	<link rel="stylesheet" href="{THEME}/css/styles.css">
	{headers}
</head>
<body class="wink">
	{AJAX}
	<div class="layout">
		[available=main]
		<div class="promo-bar">
			<div class="container promo-bar__inner">
				<span class="promo-bar__text">ТВ-каналы, фильмы и сериалы в одной подписке — <strong>7 дней бесплатно</strong></span>
				<a href="{registration-link}" class="promo-bar__btn">Подробнее</a>
			</div>
		</div>
		[/available=main]

		<header class="header" id="header">
			<div class="container header__inner">
				<div class="header__left">
					<button class="burger" id="burger" type="button" aria-label="Меню">
						<span></span><span></span><span></span>
					</button>
					<a href="/" class="logo" aria-label="Wink">
						<img src="{THEME}/images/wink-logo.svg" alt="Wink" class="logo__img" width="100" height="26">
					</a>
					<nav class="nav" id="nav">
						<ul class="nav__list">
							<li><a href="/" class="nav__link nav__link--active">Главная</a></li>
							<li><a href="/index.php?do=cat&category=tv" class="nav__link">ТВ-каналы</a></li>
							<li><a href="/index.php?do=cat&category=films" class="nav__link">Фильмы</a></li>
							<li><a href="/index.php?do=cat&category=series" class="nav__link">Сериалы</a></li>
							<li><a href="/index.php?do=cat&category=kids" class="nav__link">Детям</a></li>
							<li><a href="/index.php?do=cat&category=sport" class="nav__link">Спорт</a></li>
							{catmenu}
						</ul>
					</nav>
				</div>
				<div class="header__right">
					<form method="post" action="{search_url}" class="search">
						<button type="submit" class="search__icon-btn" aria-label="Поиск">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
						</button>
						<input type="text" name="story" placeholder="Поиск" autocomplete="off" class="search__input">
					</form>
					<div class="auth">
						[not-logged]
							<a href="{login-link}" class="auth__link">Вход</a>
							<span class="auth__sep">|</span>
							<a href="{registration-link}" class="auth__link">Регистрация</a>
						[/not-logged]
						[logged]
							<a href="{profile-link}" class="auth__profile" title="{login}">
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
							</a>
							<a href="{logout-link}" class="auth__link">Выйти</a>
						[/logged]
					</div>
				</div>
			</div>
		</header>

		<div class="info-bar">{info}</div>

		[available=main]
		<section class="hero">
			<div class="hero__slider" id="heroSlider">
				{custom template="shortstory-hero" limit="5" order="rand" cache="yes"}
			</div>
			<div class="hero__fade"></div>
		</section>
		[/available=main]

		<main class="main">
			[not-available=main]
			<div class="container">
				<div class="speedbar"><a href="/">Главная</a>{speedbar}</div>
			</div>
			[/not-available=main]

			[available=main]
			<div class="content-rows">
				<section class="row-section">
					<div class="row-section__head container">
						<h2 class="row-section__title">Новинки</h2>
					</div>
					<div class="row-scroll container" data-scroll-row>
						{custom template="shortstory-poster" limit="20" order="date" cache="yes"}
					</div>
				</section>

				<section class="row-section">
					<div class="row-section__head container">
						<h2 class="row-section__title">Выбор зрителей</h2>
					</div>
					<div class="row-scroll container" data-scroll-row>
						{custom template="shortstory-poster" limit="20" order="reads" cache="yes"}
					</div>
				</section>

				<section class="row-section">
					<div class="row-section__head container">
						<h2 class="row-section__title">Лучшее в HD</h2>
						<p class="row-section__subtitle">Смотрите в отличном качестве на любом устройстве</p>
					</div>
					<div class="row-scroll container" data-scroll-row>
						{custom template="shortstory-poster" limit="20" order="rating" cache="yes"}
					</div>
				</section>

				<section class="row-section">
					<div class="row-section__head container">
						<h2 class="row-section__title">Все фильмы и сериалы</h2>
					</div>
					<div class="container">
						<div class="grid grid--catalog">
							{content}
						</div>
						<div class="pagination-wrap">{navigation}</div>
					</div>
				</section>
			</div>
			[/available=main]

			[not-available=main]
			<div class="container page-content">
				{content}
			</div>
			[/not-available=main]
		</main>

		<footer class="footer">
			<div class="container">
				<div class="footer__grid">
					<div class="footer__brand">
						<a href="/" class="logo logo--footer">
							<img src="{THEME}/images/wink-logo.svg" alt="Wink" width="90" height="24">
						</a>
						<p class="footer__desc">Онлайн-кинотеатр Wink — ТВ-каналы, фильмы, сериалы и спортивные трансляции в одной подписке.</p>
						<div class="footer__apps">
							<span class="footer__app-badge">App Store</span>
							<span class="footer__app-badge">Google Play</span>
							<span class="footer__app-badge">RuStore</span>
						</div>
					</div>
					<div class="footer__col">
						<h4 class="footer__title">О сервисе</h4>
						<ul class="footer__links">
							<li><a href="/index.php?do=static&page=about">О Wink</a></li>
							<li><a href="/index.php?do=static&page=subscriptions">Подписки</a></li>
							<li><a href="/">Блог</a></li>
						</ul>
					</div>
					<div class="footer__col">
						<h4 class="footer__title">Помощь</h4>
						<ul class="footer__links">
							<li><a href="/index.php?do=feedback">Техподдержка</a></li>
							<li><a href="/index.php?do=static&page=devices">Устройства</a></li>
							<li><a href="/index.php?do=static&page=faq">FAQ</a></li>
						</ul>
					</div>
					<div class="footer__col">
						<h4 class="footer__title">Правовая информация</h4>
						<ul class="footer__links">
							<li><a href="/index.php?do=static&page=rules">Пользовательское соглашение</a></li>
							<li><a href="/index.php?do=static&page=privacy">Политика конфиденциальности</a></li>
						</ul>
					</div>
				</div>
				<div class="footer__bottom">
					<span>&copy; {date=Y} Wink. Все права защищены.</span>
					<span class="footer__age">18+</span>
				</div>
			</div>
		</footer>
	</div>

	<button class="scroll-top" id="scrollTop" type="button" aria-label="Наверх">
		<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m18 15-6-6-6 6"/></svg>
	</button>

	<script src="{THEME}/js/app.js"></script>
</body>
</html>

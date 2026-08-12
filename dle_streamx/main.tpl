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
	<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
	<link rel="stylesheet" href="{THEME}/css/styles.css">
	{headers}
</head>
<body class="theme-dark">
	{AJAX}
	<div class="layout">
		<header class="header" id="header">
			<div class="container header__inner">
				<div class="header__left">
					<button class="burger" id="burger" type="button" aria-label="Меню">
						<span></span><span></span><span></span>
					</button>
					<a href="/" class="logo" aria-label="На главную">
						<span class="logo__icon">▶</span>
						<span class="logo__text">StreamX</span>
					</a>
					<nav class="nav" id="nav">
						<ul class="nav__list">
							<li><a href="/" class="nav__link">Главная</a></li>
							{catmenu}
						</ul>
					</nav>
				</div>
				<div class="header__right">
					<form method="post" action="{search_url}" class="search">
						<input type="text" name="story" placeholder="Фильмы, сериалы, актёры..." autocomplete="off" class="search__input">
						<button type="submit" class="search__btn" aria-label="Поиск">
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
						</button>
					</form>
					<div class="auth">
						[not-logged]
							<a href="{login-link}" class="btn btn--ghost btn--sm">Войти</a>
							<a href="{registration-link}" class="btn btn--primary btn--sm">Подписка</a>
						[/not-logged]
						[logged]
							<a href="{profile-link}" class="auth__profile">
								<span class="auth__avatar">{login}</span>
							</a>
							<a href="{logout-link}" class="btn btn--ghost btn--sm">Выйти</a>
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
		[/available]

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
						<h2 class="row-section__title">Популярное</h2>
						<a href="/index.php?do=cat&category=films" class="row-section__more">Смотреть все →</a>
					</div>
					<div class="row-scroll container" data-scroll-row>
						{custom template="shortstory-poster" limit="16" order="reads" cache="yes"}
					</div>
				</section>

				<section class="row-section">
					<div class="row-section__head container">
						<h2 class="row-section__title">Новинки</h2>
					</div>
					<div class="row-scroll container" data-scroll-row>
						{custom template="shortstory-poster" limit="16" order="date" cache="yes"}
					</div>
				</section>

				<section class="row-section">
					<div class="row-section__head container">
						<h2 class="row-section__title">Высокий рейтинг</h2>
					</div>
					<div class="row-scroll container" data-scroll-row>
						{custom template="shortstory-poster" limit="16" order="rating" cache="yes"}
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
						<div class="logo">
							<span class="logo__icon">▶</span>
							<span class="logo__text">StreamX</span>
						</div>
						<p class="footer__desc">Онлайн-кинотеатр нового поколения. Смотрите фильмы и сериалы в HD и 4K качестве на любом устройстве.</p>
						<div class="footer__apps">
							<span class="footer__app-badge">iOS</span>
							<span class="footer__app-badge">Android</span>
							<span class="footer__app-badge">Smart TV</span>
						</div>
					</div>
					<div class="footer__col">
						<h4 class="footer__title">Каталог</h4>
						<ul class="footer__links">
							<li><a href="/">Главная</a></li>
							{catmenu}
						</ul>
					</div>
					<div class="footer__col">
						<h4 class="footer__title">Помощь</h4>
						<ul class="footer__links">
							<li><a href="/index.php?do=feedback">Обратная связь</a></li>
							<li><a href="/index.php?do=static&page=rules">Правила</a></li>
							<li><a href="/index.php?do=static&page=privacy">Конфиденциальность</a></li>
						</ul>
					</div>
					<div class="footer__col">
						<h4 class="footer__title">Подписка</h4>
						<p class="footer__text">Первые 7 дней бесплатно. Отмена в любой момент.</p>
						[not-logged]
						<a href="{registration-link}" class="btn btn--primary">Попробовать бесплатно</a>
						[/not-logged]
					</div>
				</div>
				<div class="footer__bottom">
					<span>&copy; {date=Y} StreamX. Все права защищены.</span>
					<span class="footer__age">18+</span>
				</div>
			</div>
		</footer>
	</div>

	<button class="scroll-top" id="scrollTop" type="button" aria-label="Наверх">↑</button>

	<script src="{THEME}/js/app.js"></script>
</body>
</html>

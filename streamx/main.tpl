<!DOCTYPE html>
<html lang="ru">
<head>
	{headers}
	<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
	<link rel="preconnect" href="https://fonts.googleapis.com">
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
	<link href="https://fonts.googleapis.com/css2?family=Onest:wght@400;500;600;700&family=Unbounded:wght@500;700;800&display=swap" rel="stylesheet">
	<link rel="stylesheet" href="{THEME}/css/engine.css">
	<link rel="stylesheet" href="{THEME}/css/styles.css">
</head>
<body>
	<div class="sx-bg" aria-hidden="true"></div>
	{AJAX}

	<header class="sx-header" id="sx-header">
		<div class="sx-container sx-header__inner">
			<button class="sx-burger" type="button" data-sx-nav aria-label="Меню">
				<span></span><span></span><span></span>
			</button>

			<a class="sx-logo" href="/">
				<span class="sx-logo__mark">S</span>
				<span class="sx-logo__text">StreamX</span>
			</a>

			<nav class="sx-nav" id="sx-nav">
				<a href="/">Главная</a>
				<a href="/films/">Фильмы</a>
				<a href="/series/">Сериалы</a>
				<a href="/cartoons/">Мультфильмы</a>
				<a href="/top/">Топ</a>
			</nav>

			<form class="sx-search" method="post">
				<input type="hidden" name="do" value="search">
				<input type="hidden" name="subaction" value="search">
				<input class="sx-search__input" type="text" name="story" placeholder="Фильмы, сериалы, актёры…" autocomplete="off">
				<button class="sx-search__btn" type="submit" aria-label="Найти">
					<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>
				</button>
			</form>

			<div class="sx-auth">
				{login}
			</div>
		</div>
	</header>

	<main class="sx-main">
		{info}

		[available=main]
		<section class="sx-hero" data-sx-hero>
			<div class="sx-hero__track" data-sx-hero-track>
				{custom limit="6" template="shortstory-hero" order="date" cache="yes"}
			</div>
			<div class="sx-hero__dots" data-sx-hero-dots></div>
		</section>

		<section class="sx-section">
			<div class="sx-container">
				<div class="sx-section__head">
					<h2 class="sx-section__title">Новинки</h2>
					<a class="sx-section__more" href="/">Смотреть все</a>
				</div>
				<div class="sx-rail" data-sx-rail>
					<button class="sx-rail__nav sx-rail__nav--prev" type="button" data-sx-rail-prev aria-label="Назад">‹</button>
					<div class="sx-rail__viewport" data-sx-rail-viewport>
						<div class="sx-rail__row">
							{custom limit="16" template="shortstory" order="date" cache="yes"}
						</div>
					</div>
					<button class="sx-rail__nav sx-rail__nav--next" type="button" data-sx-rail-next aria-label="Вперёд">›</button>
				</div>
			</div>
		</section>

		<section class="sx-section">
			<div class="sx-container">
				<div class="sx-section__head">
					<h2 class="sx-section__title">Фильмы</h2>
					<a class="sx-section__more" href="/films/">Смотреть все</a>
				</div>
				<div class="sx-rail" data-sx-rail>
					<button class="sx-rail__nav sx-rail__nav--prev" type="button" data-sx-rail-prev aria-label="Назад">‹</button>
					<div class="sx-rail__viewport" data-sx-rail-viewport>
						<div class="sx-rail__row">
							{custom category="1" limit="16" template="shortstory" order="date" cache="yes"}
						</div>
					</div>
					<button class="sx-rail__nav sx-rail__nav--next" type="button" data-sx-rail-next aria-label="Вперёд">›</button>
				</div>
			</div>
		</section>

		<section class="sx-section">
			<div class="sx-container">
				<div class="sx-section__head">
					<h2 class="sx-section__title">Сериалы</h2>
					<a class="sx-section__more" href="/series/">Смотреть все</a>
				</div>
				<div class="sx-rail" data-sx-rail>
					<button class="sx-rail__nav sx-rail__nav--prev" type="button" data-sx-rail-prev aria-label="Назад">‹</button>
					<div class="sx-rail__viewport" data-sx-rail-viewport>
						<div class="sx-rail__row">
							{custom category="2" limit="16" template="shortstory" order="date" cache="yes"}
						</div>
					</div>
					<button class="sx-rail__nav sx-rail__nav--next" type="button" data-sx-rail-next aria-label="Вперёд">›</button>
				</div>
			</div>
		</section>

		<section class="sx-section sx-section--last">
			<div class="sx-container">
				<div class="sx-section__head">
					<h2 class="sx-section__title">Популярное</h2>
				</div>
				<div class="sx-rail" data-sx-rail>
					<button class="sx-rail__nav sx-rail__nav--prev" type="button" data-sx-rail-prev aria-label="Назад">‹</button>
					<div class="sx-rail__viewport" data-sx-rail-viewport>
						<div class="sx-rail__row">
							{custom limit="16" template="shortstory" order="reads" cache="yes"}
						</div>
					</div>
					<button class="sx-rail__nav sx-rail__nav--next" type="button" data-sx-rail-next aria-label="Вперёд">›</button>
				</div>
			</div>
		</section>
		[/available]

		[not-available=main]
		<div class="sx-container sx-page">
			{speedbar}
			<div class="sx-grid">
				{content}
			</div>
		</div>
		[/not-available]
	</main>

	<footer class="sx-footer">
		<div class="sx-container sx-footer__inner">
			<div class="sx-footer__brand">
				<a class="sx-logo" href="/">
					<span class="sx-logo__mark">S</span>
					<span class="sx-logo__text">StreamX</span>
				</a>
				<p>Онлайн-кинотеатр нового поколения. Фильмы и сериалы в высоком качестве.</p>
			</div>
			<div class="sx-footer__cols">
				<div>
					<h4>Каталог</h4>
					<a href="/films/">Фильмы</a>
					<a href="/series/">Сериалы</a>
					<a href="/cartoons/">Мультфильмы</a>
				</div>
				<div>
					<h4>Помощь</h4>
					<a href="/index.php?do=feedback">Обратная связь</a>
					<a href="/rules.html">Правила</a>
					<a href="/index.php?do=stats">Статистика</a>
				</div>
			</div>
			<div class="sx-footer__copy">© {date=Y} StreamX</div>
		</div>
	</footer>

	<script src="{THEME}/js/app.js" defer></script>
</body>
</html>

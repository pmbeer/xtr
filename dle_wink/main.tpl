<!DOCTYPE html>
<html lang="ru">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>{title}</title>
	<meta name="description" content="{meta_description}">
	<meta name="keywords" content="{meta_keywords}">
	<link rel="preconnect" href="https://block.wink.ru" crossorigin>
	<link rel="stylesheet" href="{THEME}/css/wink.css">
	{headers}
</head>
<body class="wink">
	{AJAX}
	<div class="layout" id="layout">
		{include file="modules/promo.tpl"}
		{include file="modules/header.tpl"}

		<div class="info-bar">{info}</div>

		[available=main]
		<section class="hero" id="hero">
			<div class="hero__slider" id="heroSlider">
				{custom template="shortstory-hero" limit="5" order="rand" cache="yes"}
			</div>
			<div class="hero__fade"></div>
			<div class="hero__dots" id="heroDots"></div>
		</section>
		[/available=main]

		<main class="main">
			[not-available=main]
			<div class="container"><div class="speedbar"><a href="/">Wink</a>{speedbar}</div></div>
			[/not-available=main]

			[available=main]
			<div class="content-rows">
				[logged]
				<section class="row-section row-section--continue">
					<div class="row-section__head container">
						<h2 class="row-section__title">Продолжить просмотр</h2>
					</div>
					<div class="row-scroll row-scroll--wide container" data-scroll-row>
						{custom template="shortstory-continue" limit="12" order="date" cache="no"}
					</div>
				</section>
				[/logged]

				<section class="row-section">
					<div class="row-section__head container"><h2 class="row-section__title">Новинки</h2></div>
					<div class="row-scroll container" data-scroll-row>
						{custom template="shortstory-poster" limit="24" order="date" cache="yes"}
					</div>
				</section>

				<section class="row-section">
					<div class="row-section__head container"><h2 class="row-section__title">Выбор зрителей</h2></div>
					<div class="row-scroll container" data-scroll-row>
						{custom template="shortstory-poster" limit="24" order="reads" cache="yes"}
					</div>
				</section>

				<section class="row-section">
					<div class="row-section__head container">
						<h2 class="row-section__title">Любимки СТС и ТНТ на Wink</h2>
						<p class="row-section__subtitle">Ждать эфира не нужно: смотрите сериалы и шоу телеканалов в любое время</p>
					</div>
					<div class="row-scroll container" data-scroll-row>
						{custom category="series" template="shortstory-poster" limit="20" order="reads" cache="yes"}
					</div>
				</section>

				<section class="row-section">
					<div class="row-section__head container">
						<h2 class="row-section__title">Wink Originals</h2>
						<p class="row-section__subtitle">Лучшие сериалы из линейки оригинальных проектов Wink</p>
					</div>
					<div class="row-scroll container" data-scroll-row>
						{custom category="originals" template="shortstory-poster" limit="20" order="rating" cache="yes"}
					</div>
				</section>

				<section class="row-section">
					<div class="row-section__head container"><h2 class="row-section__title">Все фильмы и сериалы</h2></div>
					<div class="container">
						<div class="grid grid--catalog">{content}</div>
						<div class="pagination-wrap">{navigation}</div>
					</div>
				</section>
			</div>
			[/available=main]

			[not-available=main]
			<div class="page-content">{content}</div>
			[/not-available=main]
		</main>

		{include file="modules/footer.tpl"}
	</div>

	<button class="scroll-top" id="scrollTop" type="button" aria-label="Наверх">
		<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m18 15-6-6-6 6"/></svg>
	</button>

	<div class="modal" id="shareModal" hidden>
		<div class="modal__backdrop" data-modal-close></div>
		<div class="modal__dialog">
			<h3 class="modal__title">Поделиться</h3>
			<input type="text" class="modal__input" value="{full-link}" readonly id="shareLink">
			<button type="button" class="btn btn--primary btn--block" data-copy-link>Скопировать ссылку</button>
			<button type="button" class="modal__close" data-modal-close>×</button>
		</div>
	</div>

	<script src="{THEME}/js/wink.js"></script>
</body>
</html>

<!DOCTYPE html>
<html lang="ru">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>{title}</title>
	<meta name="description" content="{meta_description}">
	<meta name="keywords" content="{meta_keywords}">
	<link rel="stylesheet" href="{THEME}/css/styles.css">
	{headers}
</head>
<body class="theme-dark">
	<div class="layout">
		<header class="header">
			<div class="container">
				<div class="header__left">
					<a href="/" class="logo">StreamX</a>
					<nav class="nav">
						<ul>
							<li><a href="/">Главная</a></li>
							<li><a href="/films">Фильмы</a></li>
							<li><a href="/series">Сериалы</a></li>
							<li><a href="/cartoons">Мультфильмы</a></li>
						</ul>
					</nav>
				</div>
				<div class="header__right">
					<form method="post" action="{search_url}" class="search">
						<input type="text" name="story" placeholder="Поиск фильмов" autocomplete="off">
						<button type="submit">Найти</button>
					</form>
					<div class="auth">
						[not-logged]
							<a href="{registration-link}">Регистрация</a>
							<a href="{login-link}">Войти</a>
						[/not-logged]
						[logged]
							<a href="{profile-link}">{login}</a>
							<a href="{logout-link}">Выйти</a>
						[/logged]
					</div>
				</div>
			</div>
		</header>
		<main class="main container">
			{content}
		</main>
		<footer class="footer">
			<div class="container">
				<div class="footer__grid">
					<div>
						<div class="logo">StreamX</div>
						<p>Онлайн-кинотеатр. Просмотр фильмов и сериалов в высоком качестве.</p>
					</div>
					<div>
						<h4>Разделы</h4>
						<ul>
							<li><a href="/films">Фильмы</a></li>
							<li><a href="/series">Сериалы</a></li>
							<li><a href="/cartoons">Мультфильмы</a></li>
						</ul>
					</div>
					<div>
						<h4>О проекте</h4>
						<ul>
							<li><a href="/rules.html">Правила</a></li>
							<li><a href="/feedback.html">Обратная связь</a></li>
						</ul>
					</div>
				</div>
				<div class="footer__copy">&copy; {date=d} {website_title}</div>
			</div>
		</footer>
	</div>
	<script src="{THEME}/js/app.js"></script>
	{AJAX}
</body>
</html>

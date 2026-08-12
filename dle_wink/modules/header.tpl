<header class="header" id="header">
	<div class="container header__inner">
		<div class="header__left">
			<button class="burger" id="burger" type="button" aria-label="Меню"><span></span><span></span><span></span></button>
			<a href="/" class="logo" aria-label="Wink">
				<span class="logo__mark" aria-hidden="true"></span>
				<span class="logo__word">WINK</span>
			</a>
			<nav class="nav" id="nav">
				<ul class="nav__list">
					<li><a href="/" class="nav__link[available=main] nav__link--active[/available=main]">Главная</a></li>
					<li><a href="/index.php?do=static&page=tv" class="nav__link[static=tv] nav__link--active[/static=tv]">ТВ-каналы</a></li>
					<li><a href="/index.php?do=cat&category=movies" class="nav__link[category=movies] nav__link--active[/category=movies]">Фильмы</a></li>
					<li><a href="/index.php?do=cat&category=series" class="nav__link[category=series] nav__link--active[/category=series]">Сериалы</a></li>
					<li><a href="/index.php?do=static&page=kids" class="nav__link[static=kids] nav__link--active[/static=kids]">Детям</a></li>
					<li><a href="/index.php?do=static&page=sport" class="nav__link[static=sport] nav__link--active[/static=sport]">Спорт</a></li>
					<li><a href="/index.php?do=static&page=blog" class="nav__link">Блог</a></li>
					<li><a href="/index.php?do=static&page=audiobooks" class="nav__link">Аудиокниги</a></li>
					<li><a href="/index.php?do=static&page=services" class="nav__link[static=services] nav__link--active[/static=services]">Подписки</a></li>
					{catmenu}
				</ul>
			</nav>
		</div>
		<div class="header__right">
			<form method="post" action="{search_url}" class="search" id="searchForm">
				<button type="button" class="search__icon-btn" id="searchToggle" aria-label="Поиск">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
				</button>
				<input type="text" name="story" id="searchInput" placeholder="Поиск" autocomplete="off" class="search__input">
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

<?php
use Core\Security;
?>
<header class="header">
	<div class="container header__inner">
		<a class="logo" href="/">Wink</a>
		<nav class="nav">
			<a href="/movies">Фильмы</a>
			<a href="/series">Сериалы</a>
			<a href="/tv">ТВ-каналы</a>
			<a href="/kids">Детям</a>
		</nav>
		<form class="search" action="/search" method="get">
			<input type="text" name="q" placeholder="Поиск" value="<?= Security::e($_GET['q'] ?? '') ?>">
		</form>
		<div class="header__auth">
			<?php if (!empty($_SESSION['user_id'])): ?>
				<a class="btn" href="/profile">Мой профиль</a>
				<form action="/logout" method="post">
					<input type="hidden" name="_csrf" value="<?= Security::e(Security::csrfToken()) ?>">
					<button class="btn btn--secondary" type="submit">Выйти</button>
				</form>
			<?php else: ?>
				<a class="btn" href="/login">Войти</a>
				<a class="btn btn--primary" href="/register">Регистрация</a>
			<?php endif; ?>
		</div>
	</div>
</header>
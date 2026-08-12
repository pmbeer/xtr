[not-group=5]
<div class="sx-user">
	<button class="sx-user__btn" type="button" data-sx-user>
		<img class="sx-user__avatar" src="{foto}" alt="{login}" width="36" height="36">
		<span>{login}</span>
		[new-pm]<i class="sx-user__pm">{new-pm}</i>[/new-pm]
	</button>
	<div class="sx-user__menu" data-sx-user-menu>
		[admin-link]<a href="{admin-link}" target="_blank">Админпанель</a>[/admin-link]
		<a href="{profile-link}">Профиль</a>
		<a href="{pm-link}">Сообщения <span>{new-pm}/{all-pm}</span></a>
		<a href="{favorites-link}">Избранное <span>{favorite-count}</span></a>
		<a href="{newposts-link}">Непрочитанное</a>
		<a href="{addnews-link}">Добавить</a>
		<a class="is-danger" href="{logout-link}">Выйти</a>
	</div>
</div>
[/not-group]

[group=5]
<div class="sx-login">
	<button class="sx-btn sx-btn--ghost sx-btn--sm" type="button" data-sx-login>Войти</button>
	<a class="sx-btn sx-btn--primary sx-btn--sm" href="{registration-link}">Регистрация</a>
	<div class="sx-login__drop" data-sx-login-drop>
		<form method="post">
			<div class="sx-soc">
				[vk]<a href="{vk_url}" target="_blank" rel="noopener">VK</a>[/vk]
				[yandex]<a href="{yandex_url}" target="_blank" rel="noopener">Яндекс</a>[/yandex]
				[google]<a href="{google_url}" target="_blank" rel="noopener">Google</a>[/google]
				[mailru]<a href="{mailru_url}" target="_blank" rel="noopener">Mail</a>[/mailru]
				[odnoklassniki]<a href="{odnoklassniki_url}" target="_blank" rel="noopener">OK</a>[/odnoklassniki]
				[facebook]<a href="{facebook_url}" target="_blank" rel="noopener">FB</a>[/facebook]
			</div>
			<label class="sx-field">
				<span>{login-method}</span>
				<input type="text" name="login_name" id="login_name" placeholder="{login-method}" autocomplete="username">
			</label>
			<label class="sx-field">
				<span>Пароль</span>
				<input type="password" name="login_password" id="login_password" placeholder="Пароль" autocomplete="current-password">
			</label>
			<label class="sx-check">
				<input type="checkbox" name="login_not_save" id="login_not_save" value="1">
				<span>Чужой компьютер</span>
			</label>
			<button class="sx-btn sx-btn--primary sx-btn--block" onclick="submit();" type="submit">Войти</button>
			<input name="login" type="hidden" id="login" value="submit">
			<div class="sx-login__links">
				<a href="{registration-link}">Регистрация</a>
				<a href="{lostpassword-link}">Забыли пароль?</a>
			</div>
		</form>
	</div>
</div>
[/group]

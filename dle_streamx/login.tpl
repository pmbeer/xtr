<div class="auth-page">
	<div class="auth-card">
		<h1 class="auth-card__title">Вход в аккаунт</h1>
		<p class="auth-card__subtitle">Смотрите любимые фильмы и сериалы без ограничений</p>
		<form method="post" class="auth-form">
			<div class="form-group">
				<label for="login_name">Логин</label>
				<input type="text" name="login_name" id="login_name" placeholder="Введите логин" required>
			</div>
			<div class="form-group">
				<label for="login_password">Пароль</label>
				<input type="password" name="login_password" id="login_password" placeholder="Введите пароль" required>
			</div>
			<div class="form-group form-group--checkbox">
				<label><input type="checkbox" name="login_not_save" value="1"> Не запоминать меня</label>
			</div>
			<button type="submit" class="btn btn--primary btn--block">Войти</button>
		</form>
		<div class="auth-card__footer">
			<a href="{lostpassword-link}">Забыли пароль?</a>
			<span>·</span>
			<a href="{registration-link}">Регистрация</a>
		</div>
		<div class="auth-social">
			[vk]<a href="{vk_url}" class="auth-social__btn">ВКонтакте</a>[/vk]
			[yandex]<a href="{yandex_url}" class="auth-social__btn">Яндекс</a>[/yandex]
			[google]<a href="{google_url}" class="auth-social__btn">Google</a>[/google]
		</div>
	</div>
</div>

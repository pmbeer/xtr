<div class="auth-page">
	<div class="auth-card">
		<h1 class="auth-card__title">Вход</h1>
		<p class="auth-card__subtitle">Войдите, чтобы смотреть фильмы и сериалы</p>
		<form method="post" class="auth-form">
			<div class="form-group">
				<label for="login_name">Логин</label>
				<input type="text" name="login_name" id="login_name" placeholder="Логин" required>
			</div>
			<div class="form-group">
				<label for="login_password">Пароль</label>
				<input type="password" name="login_password" id="login_password" placeholder="Пароль" required>
			</div>
			<button type="submit" class="btn btn--primary btn--block">Войти</button>
		</form>
		<div class="auth-card__footer">
			<a href="{lostpassword-link}">Забыли пароль?</a>
			<span>·</span>
			<a href="{registration-link}">Регистрация</a>
		</div>
	</div>
</div>

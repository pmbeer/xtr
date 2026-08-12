<div class="auth-page">
	<div class="auth-card">
		<h1 class="auth-card__title">Регистрация</h1>
		<p class="auth-card__subtitle">7 дней бесплатно — отключить можно в любой момент</p>
		<form method="post" class="auth-form">
			<div class="form-group">
				<label for="name">Логин</label>
				<input type="text" name="name" id="name" placeholder="Придумайте логин" required>
			</div>
			<div class="form-group">
				<label for="email">E-mail</label>
				<input type="email" name="email" id="email" placeholder="your@email.com" required>
			</div>
			<div class="form-group">
				<label for="password1">Пароль</label>
				<input type="password" name="password1" id="password1" placeholder="Пароль" required>
			</div>
			<div class="form-group">
				<label for="password2">Повторите пароль</label>
				<input type="password" name="password2" id="password2" placeholder="Повторите пароль" required>
			</div>
			{regcode}
			<button type="submit" class="btn btn--primary btn--block">Подключить подписку</button>
		</form>
		<div class="auth-card__footer">
			<span>Уже есть аккаунт?</span>
			<a href="{login-link}">Войти</a>
		</div>
	</div>
</div>

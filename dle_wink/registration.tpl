<div class="auth-page">
	<div class="auth-card">
		<h1 class="auth-card__title">Войдите или создайте аккаунт</h1>
		<p class="auth-card__subtitle">Введите номер телефона, чтобы пользоваться Wink на любом устройстве</p>
		<form method="post" class="auth-form" id="phoneAuthForm">
			<div class="form-group">
				<label for="phone">Телефон</label>
				<div class="phone-input">
					<span class="phone-input__prefix">+7</span>
					<input type="tel" name="phone" id="phone" placeholder="(999) 123-45-67" required>
				</div>
			</div>
			<button type="submit" class="btn btn--primary btn--block">Продолжить</button>
		</form>
		<p class="auth-card__legal">Продолжая, я соглашаюсь с <a href="/index.php?do=static&page=offer">Пользовательским соглашением</a> сервиса Wink и условиями партнёрских программ.</p>
		<div class="auth-card__footer">
			<a href="{login-link}">Войти по логину</a>
		</div>
	</div>
</div>

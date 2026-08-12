<div class="auth-page">
	<div class="auth-card">
		<h1 class="auth-card__title">Восстановление пароля</h1>
		<form method="post" class="auth-form">
			<div class="form-group">
				<label for="lostname">Логин или E-mail</label>
				<input type="text" name="lostname" id="lostname" placeholder="Введите логин или email" required>
			</div>
			{sec_code}
			<button type="submit" class="btn btn--primary btn--block">Восстановить</button>
		</form>
		<div class="auth-card__footer">
			<a href="{login-link}">← Вернуться к входу</a>
		</div>
	</div>
</div>

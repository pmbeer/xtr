<div class="sx-container sx-page">
	<div class="sx-panel">
		<h1 class="sx-panel__title">Восстановление пароля</h1>
		<p class="sx-panel__lead">Укажите логин или e-mail — мы отправим инструкции.</p>
		<form method="post">
			<label class="sx-field"><span>Логин или E-mail</span><input type="text" name="lostname" id="lostname" required></label>
			[sec_code]
			<div class="sx-form__captcha">{code}<input class="sx-input" type="text" name="sec_code" id="sec_code" placeholder="Код"></div>
			[/sec_code]
			[recaptcha]<div class="sx-form__captcha">{recaptcha}</div>[/recaptcha]
			<button class="sx-btn sx-btn--primary" name="submit" type="submit">Отправить</button>
		</form>
	</div>
</div>

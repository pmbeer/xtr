<div class="sx-container sx-page">
	<div class="sx-panel">
		[registration]
		<h1 class="sx-panel__title">Регистрация</h1>
		<p class="sx-panel__lead">Создайте аккаунт, чтобы сохранять избранное и оставлять отзывы.</p>
		<div class="sx-soc sx-soc--lg">
			[vk]<a href="{vk_url}" target="_blank" rel="noopener">VK</a>[/vk]
			[yandex]<a href="{yandex_url}" target="_blank" rel="noopener">Яндекс</a>[/yandex]
			[google]<a href="{google_url}" target="_blank" rel="noopener">Google</a>[/google]
			[mailru]<a href="{mailru_url}" target="_blank" rel="noopener">Mail</a>[/mailru]
			[odnoklassniki]<a href="{odnoklassniki_url}" target="_blank" rel="noopener">OK</a>[/odnoklassniki]
			[facebook]<a href="{facebook_url}" target="_blank" rel="noopener">FB</a>[/facebook]
		</div>
		<form method="post" name="registration">
			<label class="sx-field"><span>Логин</span><input type="text" name="name" id="name" required></label>
			<label class="sx-field"><span>E-mail</span><input type="email" name="email" id="email" required></label>
			<label class="sx-field"><span>Пароль</span><input type="password" name="password1" id="password1" required></label>
			<label class="sx-field"><span>Повторите пароль</span><input type="password" name="password2" id="password2" required></label>
			{xfields}
			[sec_code]
			<div class="sx-form__captcha">{reg_code}<input class="sx-input" type="text" name="sec_code" id="sec_code" placeholder="Код"></div>
			[/sec_code]
			[recaptcha]<div class="sx-form__captcha">{recaptcha}</div>[/recaptcha]
			[question]
			<div class="sx-form__captcha"><label>{question}</label><input class="sx-input" type="text" name="question_answer" id="question_answer"></div>
			[/question]
			<button class="sx-btn sx-btn--primary" name="submit" type="submit">Зарегистрироваться</button>
		</form>
		[/registration]

		[validation]
		<h1 class="sx-panel__title">Активация аккаунта</h1>
		<p class="sx-panel__lead">Заполните дополнительные данные профиля.</p>
		<form method="post" name="registration">
			<label class="sx-field"><span>Имя</span><input type="text" name="fullname" id="fullname"></label>
			<label class="sx-field"><span>Местоположение</span><input type="text" name="land" id="land"></label>
			<label class="sx-field"><span>О себе</span><textarea name="info" id="info" rows="5"></textarea></label>
			<label class="sx-field"><span>Аватар</span><input type="file" name="image" id="image"></label>
			{xfields}
			<button class="sx-btn sx-btn--primary" name="submit" type="submit">Сохранить</button>
		</form>
		[/validation]
	</div>
</div>

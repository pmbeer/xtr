<div class="sx-form sx-form--comment">
	<div class="sx-form__title">{title}</div>
	[not-logged]
	<div class="sx-form__row">
		<input type="text" name="name" id="name" placeholder="Имя" value="{guest-name}">
		<input type="email" name="mail" id="mail" placeholder="E-mail" value="{guest-mail}">
	</div>
	[/not-logged]
	<div class="sx-editor">{editor}</div>
	[sec_code]
	<div class="sx-form__captcha">
		{sec_code}
		<input class="sx-input" type="text" name="sec_code" id="sec_code" placeholder="Код с картинки" maxlength="10">
	</div>
	[/sec_code]
	[recaptcha]
	<div class="sx-form__captcha">{recaptcha}</div>
	[/recaptcha]
	[question]
	<div class="sx-form__captcha">
		<label>{question}</label>
		<input class="sx-input" type="text" name="question_answer" id="question_answer" placeholder="Ответ">
	</div>
	[/question]
	[allow-comments-subscribe]
	<div class="sx-form__sub">{comments-subscribe}</div>
	[/allow-comments-subscribe]
	<button class="sx-btn sx-btn--primary" name="submit" type="submit">Отправить</button>
</div>

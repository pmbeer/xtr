<div class="sx-container sx-page">
	<div class="sx-panel">
		<h1 class="sx-panel__title">Обратная связь</h1>
		<form method="post">
			[not-logged]
			<label class="sx-field"><span>Имя</span><input type="text" name="name" maxlength="40" required></label>
			<label class="sx-field"><span>E-mail</span><input type="email" name="email" maxlength="50" required></label>
			[/not-logged]
			<label class="sx-field"><span>Получатель</span>{recipient}</label>
			<label class="sx-field"><span>Тема</span><input type="text" name="subject" maxlength="80" required></label>
			<label class="sx-field"><span>Сообщение</span><textarea name="message" rows="8" required></textarea></label>
			[attachments]
			<label class="sx-field"><span>Вложение</span><input name="attachments[]" type="file" multiple></label>
			[/attachments]
			[sec_code]
			<div class="sx-form__captcha">{code}<input class="sx-input" type="text" name="sec_code" id="sec_code" placeholder="Код"></div>
			[/sec_code]
			[recaptcha]<div class="sx-form__captcha">{recaptcha}</div>[/recaptcha]
			[question]
			<div class="sx-form__captcha"><label>{question}</label><input class="sx-input" type="text" name="question_answer" id="question_answer"></div>
			[/question]
			<button class="sx-btn sx-btn--primary" name="send_btn" type="submit">Отправить</button>
		</form>
	</div>
</div>

<div class="sx-container sx-page">
	<div class="sx-panel">
		<h1 class="sx-panel__title">{header-title}</h1>
		<form method="post" name="addnews" id="addnews" enctype="multipart/form-data">
			<label class="sx-field"><span>Заголовок</span><input type="text" name="title" id="title" value="{title}" maxlength="200" required></label>
			<label class="sx-field"><span>Категория</span>{category}</label>
			[urltag]
			<label class="sx-field"><span>ЧПУ</span><input type="text" name="alt_name" id="alt_name" value="{alt-name}"></label>
			[/urltag]
			[not-wysywyg]
			<div class="sx-bb">{bbcode}</div>
			[/not-wysywyg]
			[allow-shortstory]
			<label class="sx-field"><span>Краткое описание</span>
				[not-wysywyg]<textarea name="short_story" id="short_story" rows="8" class="wseditor">{short-story}</textarea>[/not-wysywyg]
				{shortarea}
			</label>
			[/allow-shortstory]
			[allow-fullstory]
			<label class="sx-field"><span>Полное описание</span>
				[not-wysywyg]<textarea name="full_story" id="full_story" rows="14" class="wseditor">{full-story}</textarea>[/not-wysywyg]
				{fullarea}
			</label>
			[/allow-fullstory]
			<label class="sx-field"><span>Теги</span><input type="text" name="tags" id="tags" value="{tags}" maxlength="300"></label>
			{xfields}
			<div class="sx-form__admin">{admintag}</div>
			[sec_code]
			<div class="sx-form__captcha">{sec_code}<input class="sx-input" type="text" name="sec_code" id="sec_code"></div>
			[/sec_code]
			[recaptcha]<div class="sx-form__captcha">{recaptcha}</div>[/recaptcha]
			[question]
			<div class="sx-form__captcha"><label>{question}</label><input class="sx-input" type="text" name="question_answer" id="question_answer"></div>
			[/question]
			<button class="sx-btn sx-btn--primary" type="submit" name="add">Отправить</button>
			<button class="sx-btn sx-btn--ghost" type="submit" name="nview" onclick="preview()">Предпросмотр</button>
		</form>
	</div>
</div>

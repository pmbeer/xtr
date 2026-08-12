<div class="sx-container sx-page">
	<div class="sx-panel">
		<div class="sx-pm__nav">
			[inbox]<a href="{link}">Входящие</a>[/inbox]
			[outbox]<a href="{link}">Отправленные</a>[/outbox]
			[new_pm]<a class="sx-btn sx-btn--primary sx-btn--sm" href="{link}">Написать</a>[/new_pm]
		</div>

		[pmlist]
		<div class="sx-pm__meter">Заполнено {proc-pm-limit}% из {pm-limit} {pm-progress-bar}</div>
		<div class="sx-pm__list">{pmlist}</div>
		[/pmlist]

		[newpm]
		<form method="post" name="pm">
			<label class="sx-field"><span>Кому</span><input type="text" name="name" value="{author}"></label>
			<label class="sx-field"><span>Тема</span><input type="text" name="subj" value="{subj}"></label>
			<div class="sx-editor">{editor}</div>
			[sec_code]
			<div class="sx-form__captcha">{sec_code}<input class="sx-input" type="text" name="sec_code" id="sec_code"></div>
			[/sec_code]
			[recaptcha]<div class="sx-form__captcha">{recaptcha}</div>[/recaptcha]
			<button class="sx-btn sx-btn--primary" type="submit" name="submit">Отправить</button>
		</form>
		[/newpm]

		[readpm]
		<article class="sx-pm__read">
			<header>
				<img src="{foto}" alt="{author}" width="48" height="48">
				<div>
					<strong>{author}</strong>
					<span>{date}</span>
					<span>{group-name}</span>
				</div>
			</header>
			<h2>{subj}</h2>
			<div class="sx-pm__text">{text}</div>
			<div class="sx-pm__tools">
				[reply]<a class="sx-btn sx-btn--primary sx-btn--sm" href="{link}">Ответить</a>[/reply]
				[del]<a class="sx-btn sx-btn--ghost sx-btn--sm" href="{link}">Удалить</a>[/del]
				[complaint]<a class="sx-btn sx-btn--ghost sx-btn--sm" href="{link}">Жалоба</a>[/complaint]
				[ignore]<a class="sx-btn sx-btn--ghost sx-btn--sm" href="{link}">Игнор</a>[/ignore]
			</div>
		</article>
		[/readpm]
	</div>
</div>

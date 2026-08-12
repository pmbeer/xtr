<div class="add-comment-form" id="addcomment">
	[not-logged]
	<p class="add-comment-form__login">Чтобы оставить комментарий, <a href="{login-link}">войдите</a> или <a href="{registration-link}">зарегистрируйтесь</a>.</p>
	[/not-logged]
	[logged]
	<h3 class="add-comment-form__title">Оставить комментарий</h3>
	{editor}
	[sec_code]
	<div class="form-group">
		<label>Код безопасности</label>
		{sec_code}
	</div>
	[/sec_code]
	<div class="add-comment-form__actions">
		<button type="submit" name="submit" class="btn btn--primary">Отправить</button>
	</div>
	[/logged]
</div>

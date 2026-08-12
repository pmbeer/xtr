<div class="sx-container sx-page">
	<div class="sx-panel sx-profile">
		<div class="sx-profile__head">
			<img src="{foto}" alt="{usertitle}" width="96" height="96">
			<div>
				<h1>{usertitle}</h1>
				<p>{status} · {group}</p>
				[online]<span class="sx-online">Онлайн</span>[/online]
				[offline]<span class="sx-offline">Оффлайн</span>[/offline]
			</div>
		</div>

		[not-logged]
		<ul class="sx-facts">
			<li><span>Регистрация</span><b>{registration}</b></li>
			<li><span>Последний визит</span><b>{lastdate}</b></li>
			<li><span>Публикаций</span><b>{news-num}</b></li>
			<li><span>Комментариев</span><b>{comm-num}</b></li>
			[land]<li><span>Откуда</span><b>{land}</b></li>[/land]
			[info]<li><span>О себе</span><b>{info}</b></li>[/info]
		</ul>
		[/not-logged]

		[logged]
		<form method="post" enctype="multipart/form-data">
			<label class="sx-field"><span>E-mail</span><input type="email" name="email" value="{editmail}"></label>
			<label class="sx-field"><span>Имя</span><input type="text" name="fullname" value="{fullname}"></label>
			<label class="sx-field"><span>Местоположение</span><input type="text" name="land" value="{land}"></label>
			<label class="sx-field"><span>О себе</span><textarea name="info" rows="5">{editinfo}</textarea></label>
			<label class="sx-field"><span>Подпись</span><textarea name="signature" rows="3">{editsignature}</textarea></label>
			<label class="sx-field"><span>Аватар</span><input type="file" name="image"><br>{avatar}</label>
			{xfields}
			<label class="sx-field"><span>Новый пароль</span><input type="password" name="altpass"></label>
			<label class="sx-field"><span>Повтор пароля</span><input type="password" name="password2"></label>
			<button class="sx-btn sx-btn--primary" name="submit" type="submit">Сохранить</button>
			<input type="hidden" name="do" value="user">
			<input type="hidden" name="action" value="edit">
		</form>
		[/logged]
	</div>
</div>

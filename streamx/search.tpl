<div class="sx-container sx-page">
	<div class="sx-panel">
		<h1 class="sx-panel__title">Поиск</h1>
		<form method="post">
			<input type="hidden" name="do" value="search">
			<input type="hidden" name="subaction" value="search">
			<label class="sx-field"><span>Запрос</span><input type="text" name="story" id="searchinput" placeholder="Название фильма или сериала" required></label>
			<button class="sx-btn sx-btn--primary" type="submit">Найти</button>
			<a class="sx-btn sx-btn--ghost" href="/index.php?do=search&amp;mode=advanced">Расширенный поиск</a>
		</form>
	</div>
</div>

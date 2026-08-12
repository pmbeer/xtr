<div class="page-search">
	<div class="container">
		<h1 class="page-header__title">Поиск</h1>
		[not-available=search]
		<div class="search-empty">
			<p class="row-section__subtitle">Введите запрос в строку поиска</p>
			<section class="row-section">
				<div class="row-section__head"><h2 class="row-section__title">Новинки</h2></div>
				<div class="row-scroll" data-scroll-row>{custom template="shortstory-poster" limit="16" order="date" cache="yes"}</div>
			</section>
			<section class="row-section">
				<div class="row-section__head"><h2 class="row-section__title">Лучшие сериалы по рейтингу</h2></div>
				<div class="row-scroll" data-scroll-row>{custom template="shortstory-poster" limit="16" order="rating" cache="yes"}</div>
			</section>
		</div>
		[/not-available=search]
		[available=search]
		<div class="grid grid--catalog">{content}</div>
		<div class="pagination-wrap">{navigation}</div>
		[/available=search]
	</div>
</div>

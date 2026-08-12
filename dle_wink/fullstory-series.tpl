<article class="movie-page movie-page--series">
	<div class="movie-page__hero">
		<div class="movie-page__backdrop">[image-1]<img src="{image-1}" alt="{title}">[/image-1]</div>
		<div class="movie-page__hero-fade"></div>
		<div class="container movie-page__hero-inner">
			<figure class="movie-page__poster">[image-1]<img src="{image-1}" alt="{title}">[/image-1]</figure>
			<div class="movie-page__info">
				<h1 class="movie-page__title">{title}</h1>
				<div class="movie-page__meta-line">
					[rating]<span class="movie-page__rating">{rating}</span>[/rating]
					<span>·</span>
					<span>{date=Y}, {title}</span>
					[xfgiven_seasons]<span>· {xfvalue_seasons} сезона</span>[/xfgiven_seasons]
				</div>
				<p class="movie-page__tagline">{short-story limit="120"}</p>
				<div class="movie-page__actions">
					<a href="#episodes" class="btn btn--primary btn--lg">Смотреть сериал</a>
					[xfgiven_trailer]<a href="{xfvalue_trailer}" class="btn btn--secondary btn--lg">Смотреть трейлер</a>[/xfgiven_trailer]
				</div>
				<div class="movie-page__secondary">
					<span class="action-btn">{add-favorites}{del-favorites}</span>
					<button type="button" class="action-btn" data-share-open>Поделиться</button>
					<button type="button" class="action-btn">Загрузить на устройство</button>
				</div>
			</div>
		</div>
	</div>

	<div class="container movie-page__body">
		<section class="seasons" id="episodes">
			<h2 class="movie-page__section-title">Сезоны и серии</h2>
			<div class="seasons__tabs" data-season-tabs>
				<button type="button" class="seasons__tab active" data-season="1">Сезон 1</button>
				<button type="button" class="seasons__tab" data-season="2">Сезон 2</button>
			</div>
			<div class="episodes-grid" data-episodes>
				{custom template="shortstory-episode" from="0" limit="12" cache="yes"}
			</div>
		</section>

		<div class="movie-page__player" id="player">{include file="modules/player.tpl"}</div>

		<section class="movie-page__section">
			<h2 class="movie-page__section-title">О сериале</h2>
			<div class="movie-page__text">{full-story}</div>
		</section>

		<section class="movie-page__meta-grid">
			<div class="meta-item"><span class="meta-item__label">Страна</span><span class="meta-item__value">[xfgiven_country]{xfvalue_country}[/xfgiven_country]</span></div>
			<div class="meta-item"><span class="meta-item__label">Жанр</span><span class="meta-item__value">{link-category}</span></div>
			<div class="meta-item"><span class="meta-item__label">Сезонов</span><span class="meta-item__value">[xfgiven_seasons]{xfvalue_seasons}[/xfgiven_seasons]</span></div>
		</section>

		<section class="movie-page__section">
			<h2 class="movie-page__section-title">Рейтинг</h2>
			<div class="rating-block">
				<div class="rating-block__main"><span class="rating-block__score">{rating}</span><span class="rating-block__label">Оценка пользователей Wink</span></div>
			</div>
		</section>

		[related-news]
		<section class="row-section">
			<div class="row-section__head"><h2 class="row-section__title">Похожие сериалы</h2></div>
			<div class="row-scroll" data-scroll-row>{related-news}</div>
		</section>
		[/related-news]
	</div>
</article>

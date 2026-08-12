<article class="movie-page">
	<div class="movie-page__hero">
		<div class="movie-page__backdrop">[image-1]<img src="{image-1}" alt="{title}">[/image-1]</div>
		<div class="movie-page__hero-fade"></div>
		<div class="container movie-page__hero-inner">
			<figure class="movie-page__poster">
				[image-1]<img src="{image-1}" alt="{title}">[/image-1]
				[not-image-1]<div class="movie-page__poster-placeholder">{title}</div>[/not-image-1]
			</figure>
			<div class="movie-page__info">
				<h1 class="movie-page__title">{title}</h1>
				<div class="movie-page__meta-line">
					[rating]<span class="movie-page__rating">{rating}</span>[/rating]
					<span>·</span>
					<span>{date=Y}, {title}</span>
				</div>
				<div class="movie-page__chips">
					<span class="chip">{link-category}</span>
					[xfgiven_duration]<span class="chip">{xfvalue_duration}</span>[/xfgiven_duration]
					[xfgiven_age]<span class="chip">{xfvalue_age}</span>[/xfgiven_age]
				</div>
				<div class="movie-page__actions">
					<a href="#player" class="btn btn--primary btn--lg">Смотреть фильм</a>
					[xfgiven_trailer]<a href="{xfvalue_trailer}" class="btn btn--secondary btn--lg" target="_blank">Смотреть трейлер</a>[/xfgiven_trailer]
				</div>
				<div class="movie-page__secondary">
					<span class="action-btn">{add-favorites}{del-favorites}</span>
					<button type="button" class="action-btn" data-share-open>Поделиться с друзьями</button>
					<button type="button" class="action-btn">Загрузить на устройство</button>
				</div>
			</div>
		</div>
	</div>

	<div class="container movie-page__body">
		<div class="movie-page__player" id="player">
			{include file="modules/player.tpl"}
		</div>

		<section class="movie-page__section">
			<h2 class="movie-page__section-title">О фильме</h2>
			<div class="movie-page__text">{short-story}</div>
		</section>

		<section class="movie-page__meta-grid">
			<div class="meta-item"><span class="meta-item__label">Страна</span><span class="meta-item__value">[xfgiven_country]{xfvalue_country}[/xfgiven_country][xfnotgiven_country]—[/xfnotgiven_country]</span></div>
			<div class="meta-item"><span class="meta-item__label">Жанр</span><span class="meta-item__value">{link-category}</span></div>
			<div class="meta-item"><span class="meta-item__label">Качество</span><span class="meta-item__value">[xfgiven_quality]{xfvalue_quality}[/xfgiven_quality][xfnotgiven_quality]Full HD[/xfnotgiven_quality]</span></div>
			<div class="meta-item"><span class="meta-item__label">Время</span><span class="meta-item__value">[xfgiven_duration]{xfvalue_duration}[/xfgiven_duration]</span></div>
		</section>

		<section class="movie-page__section">
			<h2 class="movie-page__section-title">Рейтинг</h2>
			<div class="rating-block">
				<div class="rating-block__main">
					<span class="rating-block__score">[rating]{rating}[/rating]</span>
					<span class="rating-block__label">Оценка пользователей Wink</span>
				</div>
				[xfgiven_kinopoisk]<div class="rating-block__ext"><strong>{xfvalue_kinopoisk}</strong> КиноПоиск</div>[/xfgiven_kinopoisk]
				[xfgiven_imdb]<div class="rating-block__ext"><strong>{xfvalue_imdb}</strong> IMDb</div>[/xfgiven_imdb]
			</div>
			{rating}
		</section>

		[xfgiven_cast]
		<section class="movie-page__section">
			<h2 class="movie-page__section-title">Актёры и съёмочная группа</h2>
			<div class="cast-scroll" data-scroll-row>{xfvalue_cast}</div>
		</section>
		[/xfgiven_cast]

		[related-news]
		<section class="row-section">
			<div class="row-section__head"><h2 class="row-section__title">Похожие</h2></div>
			<div class="row-scroll" data-scroll-row>{related-news}</div>
		</section>
		[/related-news]

		<section class="comments-section">
			<h2 class="comments-section__title">Комментарии ({comments-num})</h2>
			{addcomments}
			<div class="comments-list">{comments}</div>
		</section>
	</div>
</article>

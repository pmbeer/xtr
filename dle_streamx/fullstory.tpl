<article class="movie-page">
	<div class="movie-page__hero">
		<div class="movie-page__backdrop">
			[image-1]<img src="{image-1}" alt="{title}">[/image-1]
		</div>
		<div class="movie-page__hero-fade"></div>
		<div class="container movie-page__hero-inner">
			<figure class="movie-page__poster">
				[image-1]<img src="{image-1}" alt="{title}">[/image-1]
				[not-image-1]<div class="movie-page__poster-placeholder">{title}</div>[/not-image-1]
			</figure>
			<div class="movie-page__info">
				<h1 class="movie-page__title">{title}</h1>
				<div class="movie-page__meta">
					[rating]<span class="movie-page__rating">★ {rating}</span>[/rating]
					<span>{date=Y}</span>
					<span>{link-category}</span>
					<span>👁 {views}</span>
					<span>💬 {comments-num}</span>
				</div>
				<div class="movie-page__tags">{tags}</div>
				<div class="movie-page__actions">
					{add-favorites}
					{edit}
				</div>
			</div>
		</div>
	</div>

	<div class="container movie-page__body">
		<div class="movie-page__player">
			<div class="player">
				<div class="player__screen">
					{full-story}
				</div>
			</div>
		</div>

		<div class="movie-page__details">
			<div class="movie-page__xfields">{xfields}</div>
			<div class="movie-page__story">
				<h2>Описание</h2>
				{short-story}
			</div>
		</div>

		[related-news]
		<section class="row-section">
			<div class="row-section__head">
				<h2 class="row-section__title">Похожие фильмы</h2>
			</div>
			<div class="row-scroll" data-scroll-row>
				{related-news}
			</div>
		</section>
		[/related-news]

		<section class="comments-section">
			<h2 class="comments-section__title">Комментарии ({comments-num})</h2>
			{addcomments}
			<div class="comments-list">{comments}</div>
		</section>
	</div>
</article>

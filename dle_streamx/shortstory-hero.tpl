<div class="hero-slide">
	<div class="hero-slide__bg">
		[image-1]<img src="{image-1}" alt="{title}">[/image-1]
		[not-image-1]<div class="hero-slide__bg-fallback"></div>[/not-image-1]
	</div>
	<div class="container hero-slide__content">
		<div class="hero-slide__info">
			<span class="hero-slide__label">Рекомендуем</span>
			<h2 class="hero-slide__title">{title}</h2>
			<div class="hero-slide__meta">
				[rating]<span class="hero-slide__rating">★ {rating}</span>[/rating]
				<span>{date=Y}</span>
				<span>{link-category}</span>
				<span>{views} просмотров</span>
			</div>
			<p class="hero-slide__desc">{short-story limit="260"}</p>
			<div class="hero-slide__actions">
				<a href="{full-link}" class="btn btn--primary btn--lg">
					<span class="btn__icon">▶</span> Смотреть
				</a>
				<a href="{full-link}" class="btn btn--outline btn--lg">Подробнее</a>
			</div>
		</div>
	</div>
</div>

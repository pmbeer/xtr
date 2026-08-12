<article class="card card--list">
	<a class="card__poster" href="{full-link}">
		[image-1]<img src="{image-1}" alt="{title}" loading="lazy">[/image-1]
		[not-image-1]<div class="card__placeholder">{title}</div>[/not-image-1]
		<span class="card__rating">★ {rating}</span>
		<span class="card__play" aria-hidden="true">▶</span>
	</a>
	<div class="card__body">
		<h3 class="card__title"><a href="{full-link}">{title}</a></h3>
		<div class="card__meta">
			<span class="card__year">{date=Y}</span>
			<span class="card__cat">{link-category}</span>
			<span class="card__views">{views}</span>
		</div>
		<div class="card__desc">{short-story limit="180"}</div>
	</div>
</article>

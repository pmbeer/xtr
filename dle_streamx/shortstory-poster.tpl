<article class="poster-card">
	<a class="poster-card__link" href="{full-link}" title="{title}">
		<div class="poster-card__img">
			[image-1]<img src="{image-1}" alt="{title}" loading="lazy">[/image-1]
			[not-image-1]<div class="poster-card__placeholder">{title}</div>[/not-image-1]
			<div class="poster-card__overlay">
				<span class="poster-card__play">▶</span>
			</div>
			[rating]<span class="poster-card__badge">★ {rating}</span>[/rating]
		</div>
		<h3 class="poster-card__title">{title limit="40"}</h3>
		<div class="poster-card__meta">
			<span>{date=Y}</span>
			<span>{link-category}</span>
		</div>
	</a>
</article>

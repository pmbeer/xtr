<article class="card card--list">
	<a class="card__poster" href="{full-link}">
		[image-1]<img src="{image-1}" alt="{title}" loading="lazy">[/image-1]
		[not-image-1]<div class="card__placeholder">{title}</div>[/not-image-1]
	</a>
	<div class="card__body">
		<h3 class="card__title"><a href="{full-link}">{title}</a></h3>
		<div class="card__meta">
			[rating]<span class="card__rating">{rating}</span>[/rating]
			<span>{date=Y}</span>
			<span>{link-category}</span>
		</div>
		<div class="card__desc">{short-story limit="200"}</div>
	</div>
</article>

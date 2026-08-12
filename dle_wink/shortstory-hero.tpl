<div class="hero-slide">
	<div class="hero-slide__bg">
		[image-1]<img src="{image-1}" alt="{title}">[/image-1]
		[not-image-1]<div class="hero-slide__bg-fallback"></div>[/not-image-1]
	</div>
	<div class="container hero-slide__content">
		<div class="hero-slide__info">
			<span class="hero-slide__badge">Смотрите в подписке</span>
			<h1 class="hero-slide__title">{title}</h1>
			<p class="hero-slide__desc">{short-story limit="200"}</p>
			<div class="hero-slide__meta">
				[rating]<span class="hero-slide__rating">{rating}</span>[/rating]
				<span>{date=Y}</span>
				<span>{link-category}</span>
			</div>
			<div class="hero-slide__actions">
				<a href="{full-link}" class="btn btn--primary btn--lg">Смотреть</a>
				<a href="{registration-link}" class="btn btn--secondary btn--lg">Подключить подписку</a>
			</div>
			<p class="hero-slide__legal">Отключить можно в любой момент в Личном кабинете</p>
		</div>
	</div>
</div>

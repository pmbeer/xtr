<article class="sx-card">
	<a class="sx-card__link" href="{full-link}">
		<div class="sx-card__poster">
			[xfgiven_poster]<img src="[xfvalue_poster]" alt="{title}" loading="lazy">[/xfgiven_poster]
			[xfnotgiven_poster]
				[image-1]<img src="{image-1}" alt="{title}" loading="lazy">[/image-1]
				[not-image-1]<span class="sx-card__placeholder">{title limit="1"}</span>[/not-image-1]
			[/xfnotgiven_poster]
			<div class="sx-card__overlay">
				<span class="sx-card__play" aria-hidden="true">▶</span>
			</div>
			[xfgiven_quality]<span class="sx-card__badge">[xfvalue_quality]</span>[/xfgiven_quality]
			[xfgiven_age]<span class="sx-card__age">[xfvalue_age]</span>[/xfgiven_age]
		</div>
		<div class="sx-card__meta">
			<h3 class="sx-card__title">{title}</h3>
			<div class="sx-card__info">
				[xfgiven_year]<span>[xfvalue_year]</span>[/xfgiven_year]
				[xfnotgiven_year]<span>{date=Y}</span>[/xfnotgiven_year]
				[xfgiven_kp]<span class="sx-rate sx-rate--kp">КП [xfvalue_kp]</span>[/xfgiven_kp]
				[xfgiven_imdb]<span class="sx-rate sx-rate--imdb">IMDb [xfvalue_imdb]</span>[/xfgiven_imdb]
			</div>
		</div>
	</a>
</article>

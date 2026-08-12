[searchposts]
[fullresult]
<article class="sx-card sx-card--search">
	<a class="sx-card__link" href="{full-link}">
		<div class="sx-card__poster">
			[xfgiven_poster]<img src="[xfvalue_poster]" alt="{title}" loading="lazy">[/xfgiven_poster]
			[xfnotgiven_poster][image-1]<img src="{image-1}" alt="{title}" loading="lazy">[/image-1][/xfnotgiven_poster]
		</div>
		<div class="sx-card__meta">
			<h3 class="sx-card__title">{title}</h3>
			<div class="sx-card__info">
				[xfgiven_year]<span>[xfvalue_year]</span>[/xfgiven_year]
				<span>{date}</span>
			</div>
			<p class="sx-card__excerpt">{short-story limit="160"}</p>
		</div>
	</a>
</article>
[/fullresult]
[shortresult]
<article class="sx-search-hit">
	<a href="{full-link}">{title}</a>
	<span>{date}</span>
</article>
[/shortresult]
[/searchposts]

[searchcomments]
[fullresult]
<div class="sx-search-hit">
	<a href="{news-link}">{news-title}</a>
	<div>{comment limit="180"}</div>
	<span>{date} · {author}</span>
</div>
[/fullresult]
[shortresult]
<div class="sx-search-hit">
	<a href="{news-link}">{news-title}</a>
	<span>{date}</span>
</div>
[/shortresult]
[/searchcomments]

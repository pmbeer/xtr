<article class="sx-full">
	<div class="sx-full__hero">
		<div class="sx-full__backdrop">
			[xfgiven_backdrop]<img src="[xfvalue_backdrop]" alt="{title}">[/xfgiven_backdrop]
			[xfnotgiven_backdrop]
				[xfgiven_poster]<img src="[xfvalue_poster]" alt="{title}">[/xfgiven_poster]
				[xfnotgiven_poster][image-1]<img src="{image-1}" alt="{title}">[/image-1][/xfnotgiven_poster]
			[/xfnotgiven_backdrop]
			<div class="sx-full__shade"></div>
		</div>

		<div class="sx-container sx-full__top">
			<div class="sx-full__poster">
				[xfgiven_poster]<img src="[xfvalue_poster]" alt="{title}">[/xfgiven_poster]
				[xfnotgiven_poster]
					[image-1]<img src="{image-1}" alt="{title}">[/image-1]
					[not-image-1]<div class="sx-card__placeholder">{title limit="1"}</div>[/not-image-1]
				[/xfnotgiven_poster]
			</div>

			<div class="sx-full__intro">
				<div class="sx-full__cats">{link-category}</div>
				<h1 class="sx-full__title">{title}</h1>
				[xfgiven_slogan]<p class="sx-full__slogan">[xfvalue_slogan]</p>[/xfgiven_slogan]

				<div class="sx-full__meta">
					[xfgiven_year]<span>[xfvalue_year]</span>[/xfgiven_year]
					[xfgiven_country]<span>[xfvalue_country]</span>[/xfgiven_country]
					[xfgiven_time]<span>[xfvalue_time] мин</span>[/xfgiven_time]
					[xfgiven_age]<span class="sx-chip">[xfvalue_age]</span>[/xfgiven_age]
					[xfgiven_quality]<span class="sx-chip">[xfvalue_quality]</span>[/xfgiven_quality]
				</div>

				<div class="sx-full__rates">
					[xfgiven_kp]<div class="sx-score"><b>[xfvalue_kp]</b><span>Кинопоиск</span></div>[/xfgiven_kp]
					[xfgiven_imdb]<div class="sx-score"><b>[xfvalue_imdb]</b><span>IMDb</span></div>[/xfgiven_imdb]
					<div class="sx-score sx-score--site"><b>{rating}</b><span>На сайте</span></div>
				</div>

				<div class="sx-full__actions">
					<a class="sx-btn sx-btn--primary" href="#sx-player">Смотреть онлайн</a>
					[xfgiven_trailer]<a class="sx-btn sx-btn--ghost" href="[xfvalue_trailer]" target="_blank" rel="noopener">Трейлер</a>[/xfgiven_trailer]
					<span class="sx-fav">{add-favorites}{del-favorites}</span>
				</div>
			</div>
		</div>
	</div>

	<div class="sx-container sx-full__body">
		<div class="sx-full__main">
			<section class="sx-block" id="sx-player">
				<h2 class="sx-block__title">Смотреть онлайн</h2>
				<div class="sx-player">
					[xfgiven_player][xfvalue_player][/xfgiven_player]
					[xfnotgiven_player]
						<div class="sx-player__empty">Плеер появится после заполнения доп. поля <code>player</code></div>
					[/xfnotgiven_player]
				</div>
			</section>

			<section class="sx-block">
				<h2 class="sx-block__title">Описание</h2>
				<div class="sx-full__text">{full-story}</div>
			</section>

			<section class="sx-block">
				<h2 class="sx-block__title">Комментарии ({comments-num})</h2>
				{addcomments}
				<div class="sx-comments">{comments}</div>
			</section>
		</div>

		<aside class="sx-full__side">
			<section class="sx-block">
				<h2 class="sx-block__title">О фильме</h2>
				<ul class="sx-facts">
					[xfgiven_genre]<li><span>Жанр</span><b>[xfvalue_genre]</b></li>[/xfgiven_genre]
					[xfgiven_director]<li><span>Режиссёр</span><b>[xfvalue_director]</b></li>[/xfgiven_director]
					[xfgiven_actors]<li><span>В ролях</span><b>[xfvalue_actors]</b></li>[/xfgiven_actors]
					[xfgiven_year]<li><span>Год</span><b>[xfvalue_year]</b></li>[/xfgiven_year]
					[xfgiven_country]<li><span>Страна</span><b>[xfvalue_country]</b></li>[/xfgiven_country]
					[xfgiven_time]<li><span>Длительность</span><b>[xfvalue_time] мин</b></li>[/xfgiven_time]
					<li><span>Просмотры</span><b>{views}</b></li>
					<li><span>Дата</span><b>{date}</b></li>
				</ul>
				[tags]<div class="sx-tags">{tags}</div>[/tags]
			</section>

			<section class="sx-block">
				<h2 class="sx-block__title">Похожие</h2>
				<div class="sx-related">
					{related-news}
				</div>
			</section>
		</aside>
	</div>
</article>

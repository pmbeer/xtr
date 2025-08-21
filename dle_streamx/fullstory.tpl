<article class="full">
	<header class="full__header">
		<h1 class="full__title">{title}</h1>
		<div class="full__meta">
			<span>★ {rating}</span>
			<span>👁 {views}</span>
			<span>💬 {comments-num}</span>
			<span>{date}</span>
		</div>
	</header>
	<div class="full__grid">
		<figure class="full__poster">
			[image-1]<img src="{image-1}" alt="{title}">[/image-1]
		</figure>
		<div class="full__content">
			<div class="full__story">{full-story}</div>
			<div class="full__xfields">{xfields}</div>
			<div class="full__tags">{tags}</div>
			<div class="full__share">{add-favorites}{del-favorites}</div>
		</div>
	</div>
	<section class="comments">
		{comments}
	</section>
</article>

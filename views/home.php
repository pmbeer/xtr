<?php
function e(string $s): string { return htmlspecialchars($s, ENT_QUOTES, 'UTF-8'); }
?>
<section class="hero">
	<div class="hero-slider">
		<?php foreach (($featured ?? []) as $item): ?>
			<a class="hero-slide" href="/media/<?=e($item['slug'])?>">
				<img src="<?=e($item['poster_url'])?>" alt="<?=e($item['title'])?>">
				<div class="hero-caption">
					<h2><?=e($item['title'])?></h2>
				</div>
			</a>
		<?php endforeach; ?>
	</div>
</section>

<section class="section">
	<div class="section-header">
		<h3>В тренде</h3>
	</div>
	<div class="grid grid-scroll">
		<?php foreach (($trending ?? []) as $item): ?>
			<a class="card" href="/media/<?=e($item['slug'])?>">
				<img src="<?=e($item['poster_url'])?>" alt="<?=e($item['title'])?>">
				<div class="card-title"><?=e($item['title'])?></div>
			</a>
		<?php endforeach; ?>
	</div>
</section>

<section class="section">
	<div class="section-header">
		<h3>Новинки</h3>
	</div>
	<div class="grid grid-scroll">
		<?php foreach (($latest ?? []) as $item): ?>
			<a class="card" href="/media/<?=e($item['slug'])?>">
				<img src="<?=e($item['poster_url'])?>" alt="<?=e($item['title'])?>">
				<div class="card-title"><?=e($item['title'])?></div>
			</a>
		<?php endforeach; ?>
	</div>
</section>
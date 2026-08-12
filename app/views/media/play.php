<?php /** @var array $media */ $pageTitle = 'Смотреть: ' . $media['title']; $showPromo = false; ?>
<div class="container movie-page__body">
	<div class="movie-page__player" id="player">
		<div class="wink-player is-paused" data-player>
			<div class="wink-player__video">
				<video id="winkVideo" class="video-js vjs-big-play-centered" controls preload="auto" width="100%" height="100%"></video>
				<div class="wink-player__overlay" data-player-overlay>
					<div class="wink-player__top">
						<span class="wink-player__title"><?= e($media['title']) ?></span>
						<span class="wink-player__age"><?= e($media['age_rating'] ?? '16+') ?></span>
					</div>
					<button type="button" class="wink-player__center-btn" data-player-play aria-label="Play">
						<svg width="32" height="32" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
					</button>
					<div class="wink-player__bottom">
						<div class="wink-player__progress"><div class="wink-player__progress-bar" data-player-progress style="width:0%"></div></div>
						<div class="wink-player__controls">
							<div class="wink-player__controls-left">
								<button type="button" data-player-play>▶</button>
								<span class="wink-player__time"><span data-player-current>0:00</span> / <span data-player-duration>0:00</span></span>
							</div>
							<div class="wink-player__controls-right">
								<button type="button" data-player-settings>⚙</button>
								<button type="button" onclick="document.getElementById('winkVideo').requestFullscreen?.()">⛶</button>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>
	</div>
</div>
<script>
document.addEventListener('DOMContentLoaded', function(){
	var sources = <?= json_encode(array_map(fn($s) => ['src'=>$s['url'],'type'=>$s['mime'],'label'=>$s['quality'].'p'], $media['sources']), JSON_UNESCAPED_UNICODE) ?>;
	if (typeof videojs !== 'undefined' && sources.length) {
		var player = videojs('winkVideo', { fluid: true, playbackRates: [0.5, 0.75, 1, 1.25, 1.5, 2] });
		player.src(sources);
	}
});
</script>

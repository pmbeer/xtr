<div class="wink-player" id="winkPlayer" data-player>
	<div class="wink-player__video">
		<div class="wink-player__placeholder">{full-story}</div>
		<div class="wink-player__overlay" data-player-overlay>
			<div class="wink-player__top">
				<span class="wink-player__title">{title}</span>
				<span class="wink-player__age">18+</span>
			</div>
			<button type="button" class="wink-player__center-btn" data-player-play aria-label="Воспроизведение">
				<svg width="32" height="32" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
			</button>
			<div class="wink-player__bottom">
				<div class="wink-player__progress">
					<div class="wink-player__progress-bar" data-player-progress style="width:35%"></div>
				</div>
				<div class="wink-player__controls">
					<div class="wink-player__controls-left">
						<button type="button" data-player-play aria-label="Play/Pause">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
						</button>
						<button type="button" aria-label="Назад 10 сек">-10</button>
						<button type="button" aria-label="Вперёд 10 сек">+10</button>
						<button type="button" aria-label="С начала">↺</button>
						<span class="wink-player__time"><span data-player-current>12:34</span> / <span data-player-duration>45:00</span></span>
					</div>
					<div class="wink-player__controls-right">
						<button type="button" data-player-settings aria-label="Настройки">⚙</button>
						<button type="button" data-player-audio aria-label="Аудио и субтитры">CC</button>
						<button type="button" data-player-fullscreen aria-label="Полный экран">⛶</button>
					</div>
				</div>
			</div>
		</div>
	</div>
	<div class="wink-player__menu" data-player-menu hidden>
		<div class="wink-player__menu-panel" data-panel="settings">
			<h4>Качество</h4>
			<button type="button" class="active">Авто</button>
			<button type="button">1080p</button>
			<button type="button">720p</button>
			<button type="button">480p</button>
			<h4>Пропорции</h4>
			<button type="button" class="active">Комбинированный</button>
			<button type="button">На весь экран</button>
			<h4>Скорость</h4>
			<button type="button">0.5×</button>
			<button type="button" class="active">1×</button>
			<button type="button">1.5×</button>
			<button type="button">2×</button>
		</div>
	</div>
</div>

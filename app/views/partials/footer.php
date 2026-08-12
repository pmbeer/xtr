<footer class="footer">
	<div class="container">
		<div class="footer__grid">
			<div class="footer__brand">
				<a href="<?= e(url('/')) ?>" class="logo logo--footer"><span class="logo__mark"></span><span class="logo__word">WINK</span></a>
				<p class="footer__desc">Онлайн-кинотеатр Wink — ТВ-каналы, фильмы, сериалы и спортивные трансляции в одной подписке.</p>
				<div class="footer__apps">
					<span class="footer__app-badge">App Store</span>
					<span class="footer__app-badge">Google Play</span>
					<span class="footer__app-badge">RuStore</span>
				</div>
			</div>
			<div class="footer__col">
				<h4 class="footer__title">О сервисе</h4>
				<ul class="footer__links">
					<li><a href="<?= e(url('/subscribe')) ?>">Подписки</a></li>
					<li><a href="#">Блог</a></li>
				</ul>
			</div>
			<div class="footer__col">
				<h4 class="footer__title">Помощь</h4>
				<ul class="footer__links">
					<li><a href="#">Техподдержка</a></li>
					<li><a href="#">FAQ</a></li>
				</ul>
			</div>
			<div class="footer__col">
				<h4 class="footer__title">Правовая информация</h4>
				<ul class="footer__links">
					<li><a href="#">Соглашение</a></li>
					<li><a href="#">Конфиденциальность</a></li>
				</ul>
			</div>
		</div>
		<div class="footer__social">
			<a href="https://vk.com/wink.russia" target="_blank" rel="noopener">ВКонтакте</a>
			<a href="https://t.me/WinkRussia" target="_blank" rel="noopener">Telegram</a>
			<a href="https://youtube.com/@WinkOriginalsRussia" target="_blank" rel="noopener">YouTube</a>
		</div>
		<div class="footer__bottom">
			<span>&copy; <?= date('Y') ?> Wink. Все права защищены.</span>
			<span class="footer__age">18+</span>
		</div>
	</div>
</footer>

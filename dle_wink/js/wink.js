(function () {
	'use strict';

	var header = document.getElementById('header');
	var hero = document.getElementById('hero');

	if (header && hero) {
		header.classList.add('header--transparent');
		window.addEventListener('scroll', function () {
			var scrolled = window.scrollY > 80;
			header.classList.toggle('header--transparent', !scrolled);
		}, { passive: true });
	}

	var burger = document.getElementById('burger');
	var nav = document.getElementById('nav');
	if (burger && nav) {
		burger.addEventListener('click', function () {
			nav.classList.toggle('open');
			burger.classList.toggle('active');
		});
	}

	var promoClose = document.getElementById('promoClose');
	var promoBar = document.getElementById('promoBar');
	if (promoClose && promoBar) {
		promoClose.addEventListener('click', function () {
			promoBar.style.display = 'none';
		});
	}

	var heroSlider = document.getElementById('heroSlider');
	var heroDots = document.getElementById('heroDots');
	if (heroSlider) {
		var slides = heroSlider.querySelectorAll('.hero-slide');
		var current = 0;

		function goToSlide(i) {
			slides[current].classList.remove('active');
			current = i;
			slides[current].classList.add('active');
			if (heroDots) {
				heroDots.querySelectorAll('.hero__dot').forEach(function (d, idx) {
					d.classList.toggle('active', idx === current);
				});
			}
		}

		if (slides.length > 0) {
			slides[0].classList.add('active');
			if (heroDots && slides.length > 1) {
				slides.forEach(function (_, i) {
					var dot = document.createElement('button');
					dot.className = 'hero__dot' + (i === 0 ? ' active' : '');
					dot.type = 'button';
					dot.addEventListener('click', function () { goToSlide(i); });
					heroDots.appendChild(dot);
				});
				setInterval(function () { goToSlide((current + 1) % slides.length); }, 8000);
			}
		}
	}

	document.querySelectorAll('[data-scroll-row]').forEach(function (row) {
		var isDown = false, startX, scrollLeft;
		row.addEventListener('mousedown', function (e) {
			isDown = true;
			startX = e.pageX - row.offsetLeft;
			scrollLeft = row.scrollLeft;
		});
		row.addEventListener('mouseleave', function () { isDown = false; });
		row.addEventListener('mouseup', function () { isDown = false; });
		row.addEventListener('mousemove', function (e) {
			if (!isDown) return;
			e.preventDefault();
			row.scrollLeft = scrollLeft - (e.pageX - row.offsetLeft - startX) * 1.5;
		});
	});

	var scrollTop = document.getElementById('scrollTop');
	if (scrollTop) {
		window.addEventListener('scroll', function () {
			scrollTop.classList.toggle('visible', window.scrollY > 500);
		}, { passive: true });
		scrollTop.addEventListener('click', function () {
			window.scrollTo({ top: 0, behavior: 'smooth' });
		});
	}

	document.querySelectorAll('[data-tabs]').forEach(function (tabs) {
		tabs.querySelectorAll('.tabs__btn').forEach(function (btn) {
			btn.addEventListener('click', function () {
				tabs.querySelectorAll('.tabs__btn').forEach(function (b) { b.classList.remove('active'); });
				btn.classList.add('active');
			});
		});
	});

	document.querySelectorAll('[data-season-tabs]').forEach(function (wrap) {
		wrap.querySelectorAll('.seasons__tab').forEach(function (tab) {
			tab.addEventListener('click', function () {
				wrap.querySelectorAll('.seasons__tab').forEach(function (t) { t.classList.remove('active'); });
				tab.classList.add('active');
			});
		});
	});

	var player = document.querySelector('[data-player]');
	if (player) {
		var overlay = player.querySelector('[data-player-overlay]');
		var playBtns = player.querySelectorAll('[data-player-play]');
		var settingsBtn = player.querySelector('[data-player-settings]');
		var menu = player.querySelector('[data-player-menu]');

		playBtns.forEach(function (btn) {
			btn.addEventListener('click', function () {
				player.classList.toggle('is-paused');
			});
		});

		if (settingsBtn && menu) {
			settingsBtn.addEventListener('click', function () {
				menu.hidden = !menu.hidden;
			});
		}

		player.addEventListener('mouseleave', function () {
			if (menu) menu.hidden = true;
		});
	}

	var shareModal = document.getElementById('shareModal');
	document.querySelectorAll('[data-share-open]').forEach(function (btn) {
		btn.addEventListener('click', function () {
			if (shareModal) shareModal.hidden = false;
		});
	});
	document.querySelectorAll('[data-modal-close]').forEach(function (btn) {
		btn.addEventListener('click', function () {
			if (shareModal) shareModal.hidden = true;
		});
	});
	document.querySelectorAll('[data-copy-link]').forEach(function (btn) {
		btn.addEventListener('click', function () {
			var input = document.getElementById('shareLink');
			if (input) {
				input.select();
				navigator.clipboard && navigator.clipboard.writeText(input.value);
			}
		});
	});

	var searchToggle = document.getElementById('searchToggle');
	var searchForm = document.getElementById('searchForm');
	if (searchToggle && searchForm) {
		searchToggle.addEventListener('click', function () {
			searchForm.classList.toggle('search--open');
			var input = document.getElementById('searchInput');
			if (input) input.focus();
		});
	}

	var phoneForm = document.getElementById('phoneAuthForm');
	if (phoneForm) {
		phoneForm.addEventListener('submit', function (e) {
			e.preventDefault();
			alert('SMS-код отправлен на указанный номер (демо)');
		});
	}
})();

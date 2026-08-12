(function () {
	'use strict';

	/* Header scroll effect */
	var header = document.getElementById('header');
	if (header) {
		window.addEventListener('scroll', function () {
			header.classList.toggle('header--scrolled', window.scrollY > 50);
		}, { passive: true });
	}

	/* Mobile menu */
	var burger = document.getElementById('burger');
	var nav = document.getElementById('nav');
	if (burger && nav) {
		burger.addEventListener('click', function () {
			nav.classList.toggle('open');
			burger.classList.toggle('active');
		});
		document.addEventListener('click', function (e) {
			if (!nav.contains(e.target) && !burger.contains(e.target)) {
				nav.classList.remove('open');
				burger.classList.remove('active');
			}
		});
	}

	/* Hero slider */
	var heroSlider = document.getElementById('heroSlider');
	if (heroSlider) {
		var slides = heroSlider.querySelectorAll('.hero-slide');
		if (slides.length > 1) {
			var current = 0;
			slides[0].classList.add('active');
			setInterval(function () {
				slides[current].classList.remove('active');
				current = (current + 1) % slides.length;
				slides[current].classList.add('active');
			}, 7000);
		} else if (slides.length === 1) {
			slides[0].classList.add('active');
		}
	}

	/* Horizontal scroll rows with mouse drag */
	document.querySelectorAll('[data-scroll-row]').forEach(function (row) {
		var isDown = false;
		var startX, scrollLeft;

		row.addEventListener('mousedown', function (e) {
			isDown = true;
			row.style.cursor = 'grabbing';
			startX = e.pageX - row.offsetLeft;
			scrollLeft = row.scrollLeft;
		});
		row.addEventListener('mouseleave', function () {
			isDown = false;
			row.style.cursor = '';
		});
		row.addEventListener('mouseup', function () {
			isDown = false;
			row.style.cursor = '';
		});
		row.addEventListener('mousemove', function (e) {
			if (!isDown) return;
			e.preventDefault();
			var x = e.pageX - row.offsetLeft;
			row.scrollLeft = scrollLeft - (x - startX) * 1.5;
		});
	});

	/* Scroll to top */
	var scrollTop = document.getElementById('scrollTop');
	if (scrollTop) {
		window.addEventListener('scroll', function () {
			scrollTop.classList.toggle('visible', window.scrollY > 400);
		}, { passive: true });
		scrollTop.addEventListener('click', function () {
			window.scrollTo({ top: 0, behavior: 'smooth' });
		});
	}

	/* Lazy load fade-in for images */
	if ('IntersectionObserver' in window) {
		var imgObserver = new IntersectionObserver(function (entries) {
			entries.forEach(function (entry) {
				if (entry.isIntersecting) {
					entry.target.style.opacity = '1';
					imgObserver.unobserve(entry.target);
				}
			});
		}, { threshold: 0.1 });

		document.querySelectorAll('.poster-card__img img, .card__poster img').forEach(function (img) {
			img.style.opacity = '0';
			img.style.transition = 'opacity 0.4s ease';
			imgObserver.observe(img);
		});
	}
})();

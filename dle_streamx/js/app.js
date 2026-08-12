(function () {
	'use strict';

	var header = document.getElementById('header');
	var hero = document.querySelector('.hero');

	if (header && hero) {
		header.classList.add('header--transparent');
		window.addEventListener('scroll', function () {
			var scrolled = window.scrollY > 80;
			header.classList.toggle('header--transparent', !scrolled);
			header.classList.toggle('header--scrolled', scrolled);
		}, { passive: true });
	}

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
			}, 8000);
		} else if (slides.length === 1) {
			slides[0].classList.add('active');
		}
	}

	document.querySelectorAll('[data-scroll-row]').forEach(function (row) {
		var isDown = false;
		var startX, scrollLeft;

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
			var x = e.pageX - row.offsetLeft;
			row.scrollLeft = scrollLeft - (x - startX) * 1.5;
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
})();

(() => {
	const $ = (sel, root = document) => root.querySelector(sel);
	const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

	const header = $('#sx-header');
	const onScroll = () => {
		if (!header) return;
		header.classList.toggle('is-solid', window.scrollY > 20);
	};
	onScroll();
	window.addEventListener('scroll', onScroll, { passive: true });

	const burger = $('[data-sx-nav]');
	const nav = $('#sx-nav');
	if (burger && nav) {
		burger.addEventListener('click', () => nav.classList.toggle('is-open'));
		nav.querySelectorAll('a').forEach((a) => a.addEventListener('click', () => nav.classList.remove('is-open')));
	}

	const setupDropdown = (btnSel, wrapSel, openClass = 'is-open') => {
		const btn = $(btnSel);
		const wrap = btn && btn.closest(wrapSel);
		if (!btn || !wrap) return;
		btn.addEventListener('click', (e) => {
			e.preventDefault();
			e.stopPropagation();
			$$('.sx-login.is-open, .sx-user.is-open').forEach((el) => {
				if (el !== wrap) el.classList.remove(openClass);
			});
			wrap.classList.toggle(openClass);
		});
	};
	setupDropdown('[data-sx-login]', '.sx-login');
	setupDropdown('[data-sx-user]', '.sx-user');
	document.addEventListener('click', () => {
		$$('.sx-login.is-open, .sx-user.is-open').forEach((el) => el.classList.remove('is-open'));
	});

	const hero = $('[data-sx-hero]');
	if (hero) {
		const slides = $$('.sx-hero__slide', hero);
		const dotsWrap = $('[data-sx-hero-dots]', hero);
		let index = 0;
		let timer;

		const paint = () => {
			slides.forEach((slide, i) => slide.classList.toggle('is-active', i === index));
			if (dotsWrap) {
				$$('button', dotsWrap).forEach((btn, i) => btn.classList.toggle('is-active', i === index));
			}
		};

		if (slides.length) {
			slides[0].classList.add('is-active');
			if (dotsWrap) {
				dotsWrap.innerHTML = slides.map((_, i) => `<button type="button" aria-label="Слайд ${i + 1}"></button>`).join('');
				$$('button', dotsWrap).forEach((btn, i) => {
					btn.addEventListener('click', () => {
						index = i;
						paint();
						restart();
					});
				});
			}
			const next = () => {
				index = (index + 1) % slides.length;
				paint();
			};
			const restart = () => {
				clearInterval(timer);
				if (slides.length > 1) timer = setInterval(next, 6500);
			};
			paint();
			restart();
			hero.addEventListener('mouseenter', () => clearInterval(timer));
			hero.addEventListener('mouseleave', restart);
		}
	}

	$$('[data-sx-rail]').forEach((rail) => {
		const viewport = $('[data-sx-rail-viewport]', rail);
		const prev = $('[data-sx-rail-prev]', rail);
		const next = $('[data-sx-rail-next]', rail);
		if (!viewport) return;
		const step = () => Math.max(viewport.clientWidth * 0.8, 280);
		prev && prev.addEventListener('click', () => viewport.scrollBy({ left: -step(), behavior: 'smooth' }));
		next && next.addEventListener('click', () => viewport.scrollBy({ left: step(), behavior: 'smooth' }));
	});
})();

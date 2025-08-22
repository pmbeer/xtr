(function(){
	'use strict';
	const sliders = document.querySelectorAll('.hero-slider, .grid-scroll');
	sliders.forEach((el)=>{
		el.addEventListener('wheel', (e)=>{
			if (Math.abs(e.deltaX) < Math.abs(e.deltaY)){
				el.scrollLeft += e.deltaY;
				e.preventDefault();
			}
		}, {passive:false});
	});
})();
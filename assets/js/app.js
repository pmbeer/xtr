(function(){
	'use strict';

	// Simple draggable carousel
	var carousels = document.querySelectorAll('[data-carousel]');
	carousels.forEach(function(el){
		var isDown = false, startX = 0, scrollLeft = 0;
		el.addEventListener('mousedown', function(e){ isDown = true; startX = e.pageX - el.offsetLeft; scrollLeft = el.scrollLeft; });
		el.addEventListener('mouseleave', function(){ isDown = false; });
		el.addEventListener('mouseup', function(){ isDown = false; });
		el.addEventListener('mousemove', function(e){ if(!isDown) return; e.preventDefault(); var x = e.pageX - el.offsetLeft; var walk = (x - startX) * 1.2; el.scrollLeft = scrollLeft - walk; });
		// touch
		el.addEventListener('touchstart', function(e){ isDown = true; startX = e.touches[0].pageX - el.offsetLeft; scrollLeft = el.scrollLeft; }, {passive: true});
		el.addEventListener('touchend', function(){ isDown = false; }, {passive: true});
		el.addEventListener('touchmove', function(e){ if(!isDown) return; var x = e.touches[0].pageX - el.offsetLeft; var walk = (x - startX) * 1.2; el.scrollLeft = scrollLeft - walk; }, {passive: true});
	});
})();
document.addEventListener('DOMContentLoaded',()=>{
  document.querySelectorAll('[data-carousel]').forEach(el=>{
    el.addEventListener('wheel',e=>{ if(Math.abs(e.deltaY)>Math.abs(e.deltaX)){ e.preventDefault(); el.scrollLeft += e.deltaY; } },{passive:false});
  });
  const slider = document.querySelector('[data-slider]');
  if(slider){
    let index = 0;
    const slides = Array.from(slider.children);
    function show(i){ slides.forEach((s,k)=>{ s.style.display = (k===i)?'block':'none'; }); }
    if(slides.length){ show(0); setInterval(()=>{ index = (index+1)%slides.length; show(index); }, 5000); }
  }
});
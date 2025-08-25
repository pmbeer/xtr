document.addEventListener('DOMContentLoaded',function(){
  var toggle=document.getElementById('search-toggle');
  var bar=document.getElementById('search-bar');
  if(toggle&&bar){
    toggle.addEventListener('click',function(){
      var isHidden=bar.hasAttribute('hidden');
      if(isHidden){ bar.removeAttribute('hidden'); }
      else{ bar.setAttribute('hidden',''); }
      var input=bar.querySelector('input');
      if(input){ input.focus(); }
    });
  }
});


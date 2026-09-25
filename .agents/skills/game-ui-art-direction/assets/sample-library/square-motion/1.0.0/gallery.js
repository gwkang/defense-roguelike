const galleryImage=new Image(),items=[...document.querySelectorAll('figure')].map(e=>({e,c:e.querySelector('canvas').getContext('2d'),id:e.dataset.motion,t:0}));
items.forEach(x=>x.e.querySelector('button').onclick=()=>x.t=0);
let previous=0;galleryImage.onload=()=>{previous=performance.now();requestAnimationFrame(galleryFrame)};galleryImage.src='tile.png';
function galleryFrame(now){const delta=(now-previous)/1000;previous=now;for(const x of items){x.t=(x.t+delta)%2.8;render(x.c,galleryImage,x.id,x.t);x.e.querySelector('output').textContent=x.t.toFixed(2)+'s';}requestAnimationFrame(galleryFrame);}

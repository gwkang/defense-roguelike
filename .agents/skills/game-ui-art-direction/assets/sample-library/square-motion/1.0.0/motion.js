// D36: only one unchanged image; no emitted particles, rings, rays or auxiliary shapes.
const NAMES={snap:'01 · 또렷한 스냅',cute:'02 · 통통 바운스',breathe:'03 · 잔잔한 호흡',sway:'04 · 부드러운 흔들림',spring:'05 · 탄성 되튐',press:'06 · 눌렀다 놓기',slide:'07 · 미끄러져 정착',flip:'08 · 살짝 뒤집기',shake:'09 · 짧은 떨림',float:'10 · 떠오르며 복귀'};
const clamp=x=>Math.max(0,Math.min(1,x)),ease=x=>1-Math.pow(1-clamp(x),3);
function render(c,img,id,t){
 c.clearRect(0,0,720,480);c.fillStyle='#232526';c.fillRect(0,0,720,480);
 let x=360,y=240,sx=1,sy=1,rot=0,alpha=1,a=t-.55,pre=clamp((t-.25)/.3);
 if(t>=.25&&t<2.1){
  if(id==='snap'){if(a<0)sx=sy=1-.07*pre;else sx=sy=1+.17*Math.exp(-a*18);}
  else if(id==='cute'){if(a<0){let p=clamp((t-.4)/.15);y+=15*p;sx+=.28*p;sy-=.28*p;}else if(a<.48){let p=Math.sin(Math.PI*a/.48);y-=42*p;sx-=.13*p;sy+=.22*p;}else{let b=a-.48,d=Math.exp(-b*10)*Math.cos(b*23);y+=11*d;sx+=.22*d;sy-=.22*d;}}
  else if(id==='breathe'){let p=Math.sin(Math.PI*clamp((t-.25)/1.45));sx=sy=1+.035*p;alpha=1-.10*p;}
  else if(id==='sway'){if(a<0)rot=-.05*pre;else rot=.10*Math.exp(-a*4.5)*Math.sin(a*10+Math.PI/2);}
  else if(id==='spring'){if(a<0)x-=6*pre;else{x+=22*Math.exp(-a*5.5)*Math.cos(a*20);sx+=.07*Math.exp(-a*7)*Math.cos(a*20);}}
  else if(id==='press'){let p=a<0?pre:1-ease(a/.28);y+=5*p;sx+=.05*p;sy-=.10*p;}
  else if(id==='slide'){if(a<0)x-=24*ease(pre);else x-=24*(1-ease(a/.45));}
  else if(id==='flip'){let p=clamp((t-.25)/.95);sx=1-.62*Math.sin(Math.PI*p);rot=.055*Math.sin(Math.PI*2*p);}
  else if(id==='shake'){if(a<0)sx=sy=1-.025*pre;else{let b=Math.max(0,a-.07),p=Math.exp(-b*9);x+=6*p*Math.cos(b*48);rot=.022*p*Math.sin(b*48);}}
  else if(id==='float'){let p=Math.sin(Math.PI*clamp((t-.25)/1.25));y-=16*p;alpha=1-.35*p;}
 }
 c.save();c.translate(x,y);c.rotate(rot);c.scale(sx,sy);c.globalAlpha=alpha;c.drawImage(img,-64,-64,128,128);c.restore();
}
if(typeof module!=='undefined')module.exports={NAMES,render};

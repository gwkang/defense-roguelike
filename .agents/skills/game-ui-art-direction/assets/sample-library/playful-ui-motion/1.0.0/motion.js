const motionPreference=()=>document.querySelector('#reduce-motion').checked||matchMedia('(prefers-reduced-motion: reduce)').matches;
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const idleDelay={toy:3200,jelly:3800,sticker:4300};

function cancelVisuals(item){
  clearTimeout(item.idleTimer);
  item.animations.forEach(animation=>animation.cancel());
  item.animations=[];
  for(const element of [item.buttonVisual,item.buttonShadow,item.blockVisual,item.blockOutline,item.blockEcho,item.status,item.lamp,item.candidate]){
    element.getAnimations().forEach(animation=>animation.cancel());
  }
}


function clearTransientStyles(item){
  for(const element of [item.buttonVisual,item.buttonShadow,item.blockVisual,item.blockOutline,item.blockEcho,item.status,item.lamp,item.candidate]){
    for(const property of ['transform','opacity','filter','background'])element.style.removeProperty(property);
  }
  item.status.style.opacity='.28';
  item.blockOutline.style.opacity='.18';
  item.blockEcho.style.opacity='0';
}

function begin(item,state){
  item.generation++;
  cancelVisuals(item);
  clearTransientStyles(item);
  item.candidate.dataset.motionState=state;
  return item.generation;
}

function run(item,element,keyframes,options){
  const animation=element.animate(keyframes,{fill:'none',...options});
  item.animations.push(animation);
  return animation.finished.catch(()=>{});
}

function scheduleIdle(item){
  clearTimeout(item.idleTimer);
  if(item.hoverTarget||document.hidden)return;
  item.idleTimer=setTimeout(()=>idleMotion(item,true),idleDelay[item.kind]);
}

function finish(item,generation,label='ready'){
  if(generation!==item.generation)return false;
  cancelVisuals(item);
  clearTransientStyles(item);
  item.candidate.dataset.motionState='returned';
  item.output.textContent=label;
  if(item.hoverTarget)hoverEnter(item,item.hoverTarget);
  else scheduleIdle(item);
  return true;
}

function reducedPulse(item,label,generation){
  item.output.textContent=`${label} · reduced response`;
  return run(item,item.candidate,[{filter:'brightness(1)'},{filter:'brightness(1.12)'},{filter:'brightness(1)'}],{duration:150,easing:'ease-out'}).then(()=>finish(item,generation,`${label} · returned`));
}

function idleMotion(item,automatic=false){
  if(item.hoverTarget)return;
  const generation=begin(item,'idle');
  item.output.textContent=automatic?'idle · automatic':'idle · playing';
  if(motionPreference()){
    item.candidate.dataset.motionState='returned';
    item.output.textContent='idle · reduced stop';
    return Promise.resolve();
  }
  let jobs;
  if(item.kind==='toy'){
    jobs=[run(item,item.lamp,[
      {filter:'brightness(1)',transform:'scale(1)'},
      {offset:.42,filter:'brightness(1.48) drop-shadow(0 0 5px currentColor)',transform:'scale(1.12)'},
      {filter:'brightness(1)',transform:'scale(1)'}
    ],{duration:900,easing:'ease-in-out'})];
  }else if(item.kind==='jelly'){
    jobs=[
      run(item,item.buttonVisual,[{transform:'scale(1)'},{offset:.5,transform:'scale(1.012,1.018)'},{transform:'scale(1)'}],{duration:1350,easing:'ease-in-out'}),
      run(item,item.lamp,[{filter:'brightness(1)'},{offset:.5,filter:'brightness(1.25)'},{filter:'brightness(1)'}],{duration:1350,easing:'ease-in-out'})
    ];
  }else{
    jobs=[run(item,item.blockVisual,[
      {transform:'translateY(0) rotate(0)'},
      {offset:.5,transform:'translateY(-.8px) rotate(.5deg)'},
      {transform:'translateY(0) rotate(0)'}
    ],{duration:1200,easing:'ease-in-out'})];
  }
  return Promise.all(jobs).then(()=>finish(item,generation,'idle · long rest'));
}

function hoverEnter(item,target){
  item.hoverTarget=target;
  const generation=begin(item,'hover');
  item.output.textContent=`hover · ${target==='button'?'action':'item'}`;
  const visual=target==='button'?item.buttonVisual:item.blockVisual;
  const outline=target==='block'?item.blockOutline:null;
  if(motionPreference()){
    run(item,visual,[{filter:'brightness(1)'},{filter:'brightness(1.08)'}],{duration:100,easing:'ease-out',fill:'forwards'});
    return;
  }
  let keyframes;
  if(item.kind==='toy')keyframes=[{transform:'translateY(0) scale(1)'},{transform:'translateY(-3px) scale(1.015)'}];
  else if(item.kind==='jelly')keyframes=[{transform:'scale(1)'},{transform:'scale(1.025,1.018)'}];
  else keyframes=[{transform:'translateY(0) rotate(0) scale(1)'},{transform:'translateY(-1.5px) rotate(.9deg) scale(1.015)'}];
  run(item,visual,keyframes,{duration:item.kind==='jelly'?130:120,easing:'cubic-bezier(.2,.8,.2,1)',fill:'forwards'});
  if(item.kind==='sticker'&&outline)run(item,outline,[{offset:0,transform:'rotate(0) scale(1)'},{offset:.25,transform:'rotate(0) scale(1)'},{transform:'rotate(-1deg) scale(1.025)'}],{duration:120,easing:'ease-out',fill:'forwards'});
  if(generation!==item.generation)return;
}

function hoverExit(item,target){
  if(item.hoverTarget!==target)return;
  const visual=target==='button'?item.buttonVisual:item.blockVisual;
  const outline=target==='block'?item.blockOutline:null;
  const visualTransform=getComputedStyle(visual).transform;
  const visualFilter=getComputedStyle(visual).filter;
  const outlineTransform=outline?getComputedStyle(outline).transform:'none';
  item.hoverTarget=null;
  const generation=begin(item,'hover-return');
  item.output.textContent='hover · returned';
  const jobs=[run(item,visual,[{transform:visualTransform,filter:visualFilter},{transform:'none',filter:'none'}],{duration:90,easing:'ease-out'})];
  if(item.kind==='sticker'&&outline)jobs.push(run(item,outline,[{transform:outlineTransform},{transform:'none'}],{duration:100,easing:'ease-out'}));
  Promise.all(jobs).then(()=>finish(item,generation,'hover · return complete'));
}

function buttonMotion(item){
  const generation=begin(item,'press');
  item.action.focus({preventScroll:true});
  item.output.textContent='press · active';
  item.candidate.dataset.onset='immediate';
  if(motionPreference())return reducedPulse(item,'press',generation);
  let jobs;
  if(item.kind==='toy')jobs=[
    run(item,item.buttonVisual,[{transform:'translateY(0) scale(1)'},{offset:.2,transform:'translateY(5px) scale(.975,.93)'},{offset:.58,transform:'translateY(-1.5px) scale(1.035,1.028)'},{offset:.8,transform:'translateY(.5px) scale(.992)'},{transform:'translateY(0) scale(1)'}],{duration:260,easing:'linear'}),
    run(item,item.buttonShadow,[{transform:'translateY(0) scaleY(1)',opacity:1},{offset:.2,transform:'translateY(-2.5px) scaleY(.18)',opacity:.48},{offset:.58,transform:'translateY(1.2px) scaleY(1.24)',opacity:1},{transform:'translateY(0) scaleY(1)',opacity:1}],{duration:260,easing:'linear'})
  ];
  else if(item.kind==='jelly')jobs=[
    run(item,item.buttonVisual,[{transform:'scale(1)'},{offset:.19,transform:'scale(1.08,.87)'},{offset:.47,transform:'scale(.955,1.085)'},{offset:.7,transform:'scale(1.032,.975)'},{transform:'scale(1)'}],{duration:310,easing:'linear'})
  ];
  else jobs=[
    run(item,item.buttonVisual,[{transform:'rotate(0) scale(1)'},{offset:.22,transform:'rotate(-2.4deg) scale(.925)'},{offset:.58,transform:'rotate(1.6deg) scale(1.045)'},{offset:.78,transform:'rotate(-.55deg) scale(.987)'},{transform:'rotate(0) scale(1)'}],{duration:280,easing:'linear'})
  ];
  return Promise.all(jobs).then(()=>finish(item,generation,'press · returned'));
}

function blockMotion(item){
  const generation=begin(item,'block-event');
  item.output.textContent='item add-select · active';
  item.candidate.dataset.onset='immediate';
  if(motionPreference())return reducedPulse(item,'item select',generation);
  let jobs;
  if(item.kind==='toy')jobs=[
    run(item,item.blockVisual,[{transform:'translateY(11px) scale(.95)',filter:'brightness(.82)'},{offset:.48,transform:'translateY(-3px) scale(1.032)',filter:'brightness(1.12)'},{offset:.74,transform:'translateY(1.2px) scale(.992)',filter:'brightness(1)'},{transform:'translateY(0) scale(1)',filter:'brightness(1)'}],{duration:300,easing:'linear'}),
    run(item,item.blockOutline,[{opacity:.18,transform:'scale(.97)'},{offset:.18,opacity:.18,transform:'scale(.97)'},{offset:.54,opacity:1,transform:'scale(1.02)'},{opacity:.78,transform:'scale(1)'}],{duration:320,easing:'linear'}),
    run(item,item.blockEcho,[{opacity:0,transform:'scale(.94)'},{offset:.5,opacity:.75,transform:'scale(1)'},{opacity:0,transform:'scale(1.08)'}],{duration:360,easing:'ease-out'})
  ];
  else if(item.kind==='jelly')jobs=[
    run(item,item.blockVisual,[{transform:'scale(.84,1.15)'},{offset:.34,transform:'scale(1.095,.925)'},{offset:.58,transform:'scale(.955,1.055)'},{offset:.79,transform:'scale(1.024,.98)'},{transform:'scale(1)'}],{duration:390,easing:'linear'}),
    run(item,item.blockOutline,[{opacity:.1,transform:'scale(.9,1.08)'},{offset:.32,opacity:1,transform:'scale(1.08,.95)'},{offset:.68,opacity:.7,transform:'scale(.98,1.03)'},{opacity:.78,transform:'scale(1)'}],{duration:410,easing:'linear'}),
    run(item,item.blockEcho,[{opacity:0,transform:'scale(.9)'},{offset:.38,opacity:.65,transform:'scale(1.02)'},{opacity:0,transform:'scale(1.12)'}],{duration:420,easing:'ease-out'})
  ];
  else jobs=[
    run(item,item.blockVisual,[{transform:'translateY(9px) rotate(-5deg) scale(.86)',opacity:.5},{offset:.43,transform:'translateY(-3px) rotate(2.3deg) scale(1.05)',opacity:1},{offset:.72,transform:'translateY(1.2px) rotate(-.9deg) scale(.987)',opacity:1},{transform:'translateY(0) rotate(0) scale(1)',opacity:1}],{duration:330,easing:'linear'}),
    run(item,item.blockOutline,[{opacity:0,transform:'rotate(-4deg) scale(.9)'},{offset:.08,opacity:0,transform:'rotate(-4deg) scale(.9)'},{offset:.5,opacity:1,transform:'rotate(2.2deg) scale(1.05)'},{opacity:.78,transform:'rotate(0) scale(1)'}],{duration:365,easing:'linear'}),
    run(item,item.blockEcho,[{opacity:0,transform:'rotate(-3deg) scale(.94)'},{offset:.42,opacity:.85,transform:'rotate(1deg) scale(1)'},{opacity:0,transform:'rotate(3deg) scale(1.1)'}],{duration:410,easing:'ease-out'})
  ];
  return Promise.all(jobs).then(()=>finish(item,generation,'item add-select · returned'));
}

function successMotion(item){
  const generation=begin(item,'success-event');
  item.output.textContent='success · active';
  item.candidate.dataset.onset='immediate';
  if(motionPreference())return reducedPulse(item,'success',generation);
  item.status.style.opacity='1';
  const lamp=run(item,item.lamp,[{background:'#51615a',filter:'none'},{offset:.22,background:'#76e0b5',filter:'brightness(1.7) drop-shadow(0 0 7px #76e0b5)'},{offset:.55,background:'#76e0b5',filter:'brightness(1.1)'},{background:'#76e0b5',filter:'none'}],{duration:360,easing:'linear'});
  let jobs;
  if(item.kind==='toy')jobs=[lamp,run(item,item.status,[{transform:'translateX(-10px) scale(.93)',opacity:0},{offset:.38,transform:'translateX(3px) scale(1.05)',opacity:1},{offset:.68,transform:'translateX(-1.2px) scale(.987)',opacity:1},{transform:'translateX(0) scale(1)',opacity:1}],{duration:340,easing:'linear'})];
  else if(item.kind==='jelly')jobs=[lamp,run(item,item.status,[{transform:'scale(.68,1.23)',opacity:.25},{offset:.32,transform:'scale(1.14,.88)',opacity:1},{offset:.55,transform:'scale(.94,1.085)',opacity:1},{offset:.76,transform:'scale(1.045,.975)',opacity:1},{transform:'scale(1)',opacity:1}],{duration:430,easing:'linear'}),run(item,item.blockVisual,[{transform:'scale(1)'},{offset:.28,transform:'scale(1.032,.962)'},{offset:.55,transform:'scale(.987,1.024)'},{transform:'scale(1)'}],{duration:360,easing:'linear'})];
  else jobs=[lamp,run(item,item.status,[{transform:'rotate(-8.5deg) scale(.5)',opacity:0},{offset:.43,transform:'rotate(3deg) scale(1.17)',opacity:1},{offset:.7,transform:'rotate(-1.3deg) scale(.96)',opacity:1},{transform:'rotate(0) scale(1)',opacity:1}],{duration:380,easing:'linear'}),run(item,item.blockEcho,[{opacity:0,transform:'rotate(-4deg) scale(.95)'},{offset:.5,opacity:.88,transform:'rotate(2.5deg) scale(1.03)'},{opacity:0,transform:'rotate(5deg) scale(1.14)'}],{duration:390,easing:'ease-out'})];
  return Promise.all(jobs).then(()=>finish(item,generation,'success · returned'));
}

async function hoverPreview(item){
  item.sequence++;
  const sequence=item.sequence;
  hoverEnter(item,'button');
  await wait(420);if(sequence!==item.sequence)return;
  hoverExit(item,'button');
  await wait(170);if(sequence!==item.sequence)return;
  hoverEnter(item,'block');
  await wait(420);if(sequence!==item.sequence)return;
  hoverExit(item,'block');
}

async function playAll(item){
  item.sequence++;
  const sequence=item.sequence;
  await idleMotion(item);if(sequence!==item.sequence)return;await wait(130);
  hoverEnter(item,'button');await wait(260);if(sequence!==item.sequence)return;
  item.hoverTarget=null;await buttonMotion(item);if(sequence!==item.sequence)return;await wait(90);
  await blockMotion(item);if(sequence!==item.sequence)return;await wait(110);
  await successMotion(item);if(sequence!==item.sequence)return;
  item.output.textContent='full flow · returned';
}

if(typeof document!=='undefined'){
  const items=[...document.querySelectorAll('.candidate')].map(candidate=>({
    candidate,kind:candidate.classList.contains('toy')?'toy':candidate.classList.contains('jelly')?'jelly':'sticker',
    action:candidate.querySelector('.action'),buttonVisual:candidate.querySelector('.button-visual'),buttonShadow:candidate.querySelector('.button-shadow'),
    blockSlot:candidate.querySelector('.block-slot'),blockVisual:candidate.querySelector('.block-visual'),blockOutline:candidate.querySelector('.block-outline'),blockEcho:candidate.querySelector('.block-echo'),status:candidate.querySelector('.status-chip'),lamp:candidate.querySelector('.lamp'),output:candidate.querySelector('output'),
    animations:[],sequence:0,generation:0,hoverTarget:null,idleTimer:null
  }));
  for(const item of items){
    item.action.addEventListener('pointerenter',()=>hoverEnter(item,'button'));
    item.action.addEventListener('pointerleave',()=>hoverExit(item,'button'));
    item.blockSlot.addEventListener('pointerenter',()=>hoverEnter(item,'block'));
    item.blockSlot.addEventListener('pointerleave',()=>hoverExit(item,'block'));
    item.action.addEventListener('pointerdown',()=>{item.sequence++;buttonMotion(item);});
    item.blockSlot.addEventListener('pointerdown',()=>{item.sequence++;blockMotion(item);});
    item.action.addEventListener('keydown',event=>{if((event.key==='Enter'||event.key===' ')&&!event.repeat){item.sequence++;buttonMotion(item);}});
    item.candidate.querySelectorAll('[data-play]').forEach(button=>button.addEventListener('click',()=>{
      item.sequence++;
      const mode=button.dataset.play;
      if(mode==='all')playAll(item);
      else if(mode==='idle')idleMotion(item);
      else if(mode==='hover')hoverPreview(item);
      else if(mode==='button')buttonMotion(item);
      else if(mode==='block')blockMotion(item);
      else successMotion(item);
    }));
    scheduleIdle(item);
  }
  document.querySelector('#reduce-motion').addEventListener('change',()=>items.forEach(item=>{item.sequence++;item.hoverTarget=null;begin(item,'returned');finish(item,item.generation,'setting changed · returned');}));
  document.addEventListener('visibilitychange',()=>items.forEach(item=>document.hidden?cancelVisuals(item):scheduleIdle(item)));
  window.motionItems=items;
}

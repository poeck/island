const test=require('node:test');
const assert=require('node:assert/strict');
const {step,island,calm}=require('../src/core/Motion.js');
function settle(from,to,hz,spring){
 let x=from,v=0,max=from,min=from,t=0;
 do { [x,v]=step(x,v,to,1/hz,spring); max=Math.max(max,x);min=Math.min(min,x);t+=1/hz; } while(v!==0 && t<2);
 return {x,t,max,min};
}
test('island morph rebounds visibly but settles within 450 ms at 60/125/240 Hz',()=>{
 for(const hz of [60,125,240]) {
  const {x,t,max}=settle(96,760,hz,island);
  assert.equal(x,760);assert.ok(t<=.45,`${hz} Hz settles at ${t}`);
  // ~4% of the 664 px travel: noticeable, never sloppy.
  assert.ok(max>775 && max<795,`overshoot ${max}`);
 }
});
test('chrome spring arrives without visible rebound',()=>{
 for(const hz of [60,125,240]) {
  const {x,t,max}=settle(-28,0,hz);
  assert.equal(x,0);assert.ok(t<=.4,`${hz} Hz settles at ${t}`);
  assert.ok(max<0.5,`overshoot ${max}`);
 }
 assert.deepEqual(step(-28,0,0,1/60),step(-28,0,0,1/60,calm));
});
test('rapid reversal starts from current position and velocity, then settles',()=>{
 for(const spring of [island,calm]) {
  let x=96,v=0;
  for(let i=0;i<6;i++) [x,v]=step(x,v,688,1/60,spring);
  const before=x,oldVelocity=v;
  [x,v]=step(x,v,376,1/240,spring);
  assert.ok(Math.abs(x-before)<Math.abs(oldVelocity)/200+10);
  for(let i=0;i<120;i++) [x,v]=step(x,v,376,1/240,spring);
  assert.equal(x,376); assert.equal(v,0);
 }
});
test('idle spring produces no movement and stalled frames stay finite',()=>{
 assert.deepEqual(step(148,0,148,1/60,island),[148,0]);
 const result=step(148,0,760,100,island); assert.ok(result.every(Number.isFinite));
});

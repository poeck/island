const test = require('node:test');
const assert = require('node:assert/strict');
const state = require('../src/core/State.js');

test('authentication preserves launcher and restores it after cancellation', () => {
  let s = state.reduce(state.initial(), {type:'toggle', panel:'launcher'});
  s = state.reduce(s, {type:'auth', value:true});
  assert.equal(state.mode(s), 'auth');
  s = state.reduce(s, {type:'toggle', panel:'session'});
  assert.equal(s.panel, 'launcher');
  s = state.reduce(s, {type:'auth', value:false});
  assert.equal(state.mode(s), 'launcher');
});
test('media is a persistent panel; notifications queue and OSD stays inline', () => {
  let s = state.reduce(state.initial(), {type:'toggle', panel:'media'});
  s = state.reduce(s, {type:'notification', value:true});
  s = state.reduce(s, {type:'osd', value:true});
  assert.equal(state.mode(s), 'media');
  assert.equal(state.blocksPopups(s), true);
  assert.equal(state.mode(state.reduce(s, {type:'toggle', panel:'media'})), 'osd');
  assert.equal(state.mode(state.reduce(s, {type:'dismiss'})), 'osd');
  s = state.reduce(s, {type:'toggle', panel:'launcher'});
  assert.equal(state.mode(s), 'launcher');
  assert.equal(s.osd, true);
});
test('fullscreen hides passive UI, while shortcuts, OSD and auth remain available', () => {
  let s = state.reduce(state.initial(), {type:'fullscreen', value:true});
  for (const event of [{type:'notification',value:true}]) {
    s = state.reduce(s,event); assert.equal(state.mode(s),'hidden');
  }
  assert.equal(state.mode(state.reduce(s,{type:'osd',value:true})),'osd');
  assert.equal(state.mode(state.reduce(s,{type:'toggle',panel:'session'})),'session');
  assert.equal(state.mode(state.reduce(s,{type:'auth',value:true})),'auth');
});
test('entering fullscreen closes clock and system views', () => {
  for (const panel of ['media', 'system', 'audio', 'network', 'calendar', 'bluetooth', 'weather']) {
    let s = state.reduce(state.initial(), {type:'toggle',panel});
    s = state.reduce(s, {type:'fullscreen',value:true});
    assert.equal(s.panel, '');
    assert.equal(state.mode(s), 'hidden');
  }
});
test('system panel queues notifications, keeps OSD inline, and returns after authentication', () => {
  let s = state.reduce(state.initial(), {type:'toggle',panel:'system'});
  s = state.reduce(s, {type:'notification',value:true});
  s = state.reduce(s, {type:'osd',value:true});
  assert.equal(state.mode(s), 'system');
  assert.equal(state.blocksPopups(s), true);
  s = state.reduce(s, {type:'auth',value:true});
  assert.equal(state.mode(s), 'auth');
  s = state.reduce(s, {type:'auth',value:false});
  assert.equal(state.mode(s), 'system');
});
test('locking supersedes everything and discards pending panel/OSD state', () => {
  let s = {panel:'launcher',auth:true,locked:false,fullscreen:false,osd:true,notification:true};
  s = state.reduce(s,{type:'lock',value:true});
  assert.equal(state.mode(s),'hidden'); assert.equal(s.panel,''); assert.equal(s.osd,false);
  assert.equal(state.blocksPopups(s),true);
});
test('repeated toggles and dismiss converge without modifying old state', () => {
  const original=state.initial();
  let s=original;
  for(let i=0;i<100;i++) s=state.reduce(s,{type:'toggle',panel:'notifications'});
  assert.equal(state.mode(s),'compact'); assert.deepEqual(original,state.initial());
});

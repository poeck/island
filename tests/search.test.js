const test = require('node:test');
const assert = require('node:assert/strict');
const {score,rank}=require('../src/core/Search.js');
const entries=[{id:'a',name:'Alacritty'},{id:'f',name:'Firefox',genericName:'Web Browser'}, {id:'c',name:'Files',keywords:['directory','folders']}];
test('exact/prefix matches win and subsequences work',()=>{
 assert.ok(score('fire','Firefox')>score('ff','Firefox'));
 assert.ok(score('acr','Alacritty')>0); assert.equal(score('xyz','Firefox'),-1);
 assert.equal(rank(entries,'FIRE',{})[0].id,'f');
});
test('empty search sorts recent first, then alphabetically',()=>{
 assert.deepEqual(rank(entries,'',{}).map(e=>e.id),['a','c','f']);
 assert.equal(rank(entries,' ',{f:1})[0].id,'f');
});
test('search includes generic names and keywords, excludes unrelated results',()=>{
 assert.equal(rank(entries,'browser',{})[0].id,'f');
 assert.equal(rank(entries,'folders',{})[0].id,'c');
 assert.deepEqual(rank(entries,'xyz',{}),[]);
});

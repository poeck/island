const test = require('node:test');
const assert = require('node:assert/strict');
const b = require('../src/core/Bluetooth.js');
test('connected and saved devices lead the nearby list without cloning native objects',()=>{
  const nearby={name:'A phone'}, saved={name:'Z keyboard',paired:true}, connected={name:'Headphones',connected:true,paired:true};
  const input=[nearby,saved,connected]; const result=b.sorted(input);
  assert.deepEqual(result,[connected,saved,nearby]); assert.equal(result[0],connected); assert.equal(input[0],nearby);
});
test('device identity, type and optional battery have honest fallbacks',()=>{
  assert.equal(b.name({address:'00:11:22:33:44:55'}),'00:11:22:33:44:55');
  assert.equal(b.icon({icon:'audio-headset'}),'headphones'); assert.equal(b.icon({icon:'input-keyboard'}),'keyboard');
  assert.equal(b.battery({battery:.84,batteryAvailable:true}),'84%'); assert.equal(b.battery({battery:.84}),'');
  assert.equal(b.status({pairing:true,paired:false}),'Pairing…'); assert.equal(b.status({blocked:true}),'Blocked');
});

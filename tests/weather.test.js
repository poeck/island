const test=require('node:test');const assert=require('node:assert/strict');
const weather=require('../src/core/Weather.js');
test('weather codes distinguish night, precipitation, frozen precipitation, and missing readings',()=>{
 assert.equal(weather.condition(0,false).icon,'moon');assert.equal(weather.condition(0,true).icon,'sun');
 assert.equal(weather.condition(66,true).icon,'rain');assert.equal(weather.condition(85,true).icon,'snow');
 assert.equal(weather.condition(99,true).icon,'storm');assert.equal(weather.condition(null,true).label,'Weather unavailable');
 assert.equal(weather.value(0,'°'),'0°');assert.equal(weather.value(null,'°'),'—');assert.equal(weather.direction(359),'N');
});

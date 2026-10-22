const test=require('node:test');
const assert=require('node:assert/strict');
const {select}=require('../src/core/Displays.js');
test('preferred output arrives, disappears, and reconnects',()=>{
 const laptop={name:'eDP-1',model:'Internal'},aoc={name:'DP-2',model:'Q27G4ZR'};
 const monitors=[{name:'DP-2',description:'AOC Q27G4ZR ABC123'}];
 assert.equal(select([laptop],monitors,'AOC Q27G4ZR'),laptop);
 assert.equal(select([laptop,aoc],monitors,'aoc q27g4zr'),aoc);
 assert.equal(select([laptop,aoc],[],'DP-2'),aoc);
 assert.equal(select([laptop],monitors,'DP-2'),laptop);
 assert.equal(select([laptop,aoc],monitors,'DP-2'),aoc);
 assert.equal(select([],monitors,'DP-2'),null);
});

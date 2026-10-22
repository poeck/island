const test = require('node:test');
const assert = require('node:assert/strict');
const c = require('../src/core/Calendar.js');
const key = d => [d.getFullYear(),d.getMonth()+1,d.getDate()];
test('month grid starts Monday and includes every civil day in six weeks',()=>{
  const cells=c.cells(c.civil(2026,9,21));
  assert.equal(cells.length,42); assert.equal(cells[0].getDay(),1);
  assert.deepEqual(key(cells[0]),[2026,9,28]);
  assert.deepEqual(key(cells[41]),[2026,11,8]);
  assert.equal(cells.filter(d=>d.getMonth()===9).length,31);
});
test('navigation crosses year, leap day and DST without skipping dates',()=>{
  assert.deepEqual(key(c.month(c.civil(2026,11,31),1)),[2027,1,1]);
  assert.deepEqual(key(c.day(c.civil(2024,1,28),1)),[2024,2,29]);
  assert.deepEqual(key(c.day(c.civil(2026,9,25),1)),[2026,10,26]);
  assert.equal(c.dayOfYear(c.civil(2024,11,31)),366);
  assert.equal(c.same(c.civil(2026,0,1),new Date(2026,0,1,23,59)),true);
});
test('ISO week numbers handle year boundaries',()=>{
  assert.equal(c.week(c.civil(2021,0,1)),53);
  assert.equal(c.week(c.civil(2021,0,4)),1);
  assert.equal(c.week(c.civil(2026,9,21)),43);
});

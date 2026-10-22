const test = require('node:test');
const assert = require('node:assert/strict');
const format = require('../src/core/SystemFormat.js');

test('telemetry formatting distinguishes unavailable readings from idle devices', () => {
  assert.equal(format.percent(0), '0%');
  assert.equal(format.percent(null), '—');
  assert.equal(format.temperature(null), 'Sensor unavailable');
  assert.equal(format.bytes(1024 ** 3), '1.0 GiB');
  assert.equal(format.duration(60 * 60 * 49 + 120), '2d 1h 2m');
});

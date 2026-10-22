const test = require('node:test');
const assert = require('node:assert/strict');
const {sorted, signal, speed} = require('../src/core/Network.js');
test('connected then saved networks precede stronger unfamiliar networks without copying native objects', () => {
  const networks = [
    {name:'Strong',signalStrength:1}, {name:'Home',known:true,signalStrength:.3},
    {name:'Active',connected:true,signalStrength:.2}, {name:'',signalStrength:1}
  ];
  const result = sorted(networks);
  assert.deepEqual(result.map(n=>n.name), ['Active','Home','Strong']);
  assert.equal(result[0], networks[2]);
  assert.equal(networks.length,4);
});
test('signal is bounded and link speed preserves gigabit fractions', () => {
  assert.equal(signal(.624),62); assert.equal(signal(null),0); assert.equal(signal(2),100);
  assert.equal(speed(2500),'2.5 Gbps'); assert.equal(speed(100),'100 Mbps'); assert.equal(speed(0),'');
});

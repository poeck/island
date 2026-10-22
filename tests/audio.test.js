const test = require('node:test');
const assert = require('node:assert/strict');
const audio = require('../src/core/Audio.js');
const node = (name, recording = false, ready = true) => ({ready, isSink: recording, properties: {'application.name': name}, audio: {volume: .5, muted: false}});

test('multiple application streams group without combining playback and recording', () => {
  const first = node('Browser'), second = node('Browser'), capture = node('Browser', true);
  const result = audio.groups([first, second, capture, node('Unready', false, false)]);
  assert.equal(result.length, 2);
  assert.deepEqual(result[0].nodes, [first, second]);
  assert.equal(result[1].recording, true);
});
test('application volume and mute reflect all ready streams', () => {
  const first = node('Browser'), second = node('Browser');
  first.audio.volume = .25; second.audio.volume = .75;
  assert.equal(audio.volume([first, second]), .5);
  first.audio.muted = true;
  assert.equal(audio.muted([first, second]), false);
  second.audio.muted = true;
  assert.equal(audio.muted([first, second]), true);
  assert.equal(audio.volume([null]), 0);
  assert.equal(audio.gain(2), 1);
  assert.equal(audio.gain(-1), 0);
});
test('device names and transport labels are readable without exposing node IDs', () => {
  assert.equal(audio.deviceName({description: 'Headphones', name: 'bluez_output.test'}), 'Headphones');
  assert.equal(audio.deviceKind({name: 'bluez_output.test'}), 'Bluetooth');
  assert.equal(audio.deviceKind({name: 'easyeffects_sink'}), 'Effects / virtual device');
  assert.equal(audio.deviceName(null), 'No device connected');
});

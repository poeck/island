const test = require('node:test');
const assert = require('node:assert/strict');
const text = require('../src/core/AuthText.js');

test('conversation prompts become calm field labels', () => {
  assert.equal(text.promptLabel('[sudo] password for paul: ', false), 'Password');
  assert.equal(text.promptLabel('Password: ', true), 'Password');
  assert.equal(text.promptLabel('', false), 'Password');
  assert.equal(text.promptLabel('Please enter the PIN: ', true), 'Security key PIN');
  assert.equal(text.promptLabel('PIN for token:', false), 'PIN');
  assert.equal(text.promptLabel('Verification code:', true), 'Verification code');
  assert.equal(text.promptKind('Spinning up'), 'other');
});

test('touch cues are recognized without treating prompts as cues', () => {
  assert.ok(text.isTouchCue('Please touch the device.'));
  assert.ok(text.isTouchCue('Tap your key'));
  assert.ok(!text.isTouchCue('Password:'));
  assert.ok(!text.isTouchCue(undefined));
});

test('failure copy names only the step the user actually attempted', () => {
  assert.match(text.failureMessage('password', true), /password/);
  assert.match(text.failureMessage('pin', true), /PIN/);
  assert.match(text.failureMessage('touch', true), /security key/);
  assert.doesNotMatch(text.failureMessage('', false), /security key/);
  assert.match(text.failureMessage('', true), /security key/);
});

// Exact underdamped spring solution. Retarget by changing target without resetting velocity.
// island: 32 rad/s, damping ratio .72: ~4% overshoot, a visible Dynamic Island rebound,
// settling in <450 ms for the largest panel.
// calm: 34 rad/s, damping ratio .85: ~0.6% overshoot for chrome that should just arrive.
var island = {omega: 32, zeta: 0.72};
var calm = {omega: 34, zeta: 0.85};
function step(position, velocity, target, seconds, spring) {
    var omega = (spring || calm).omega, zeta = (spring || calm).zeta;
    var dt = Math.max(0, Math.min(seconds, 0.1));
    var damp = zeta * omega, frequency = omega * Math.sqrt(1 - zeta * zeta);
    var displacement = position - target;
    var a = displacement, b = (velocity + damp * displacement) / frequency;
    var decay = Math.exp(-damp * dt), c = Math.cos(frequency * dt), s = Math.sin(frequency * dt);
    var next = target + decay * (a * c + b * s);
    var nextVelocity = decay * ((b * frequency - damp * a) * c - (a * frequency + damp * b) * s);
    if (Math.abs(next - target) < 0.2 && Math.abs(nextVelocity) < 3) return [target, 0];
    return [next, nextVelocity];
}
if (typeof module !== "undefined") module.exports = {step: step, island: island, calm: calm};

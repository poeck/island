// Presentation helpers for PAM, Polkit and sudo conversations. They only shape
// labels: the authentication modules decide what is asked and whether it passed.

function promptKind(text) {
    var value = String(text || "").toLowerCase();
    if (/\bpin\b/.test(value)) return "pin";
    if (!value.trim() || /pass(word|phrase|code)/.test(value)) return "password";
    return "other";
}

// "[sudo] password for paul: " and "Please enter the PIN:" become field labels.
function promptLabel(text, keys) {
    var kind = promptKind(text);
    if (kind === "pin") return keys ? "Security key PIN" : "PIN";
    if (kind === "password") return "Password";
    var clean = String(text).trim().replace(/^please\s+(enter\s+)?/i, "").replace(/[:：]+$/, "").trim();
    return clean ? clean.charAt(0).toUpperCase() + clean.slice(1) : "Response";
}

// pam-u2f's optional cue ("Please touch the device.") is guidance, not a prompt.
function isTouchCue(text) { return /\b(touch|tap)\b/i.test(String(text || "")); }

// kind: the last step the user acted on ("touch", "pin", "password", "other"),
// or "" when the conversation ended before any response was given.
function failureMessage(kind, keys) {
    if (kind === "touch") return "The security key wasn't confirmed. Try again.";
    if (kind === "pin") return "That PIN didn't work. Try again.";
    if (kind === "password") return "That password didn't work. Try again.";
    if (kind === "other") return "That didn't work. Try again.";
    return keys ? "Couldn't verify. Is your security key connected?" : "Authentication didn't complete.";
}

if (typeof module !== "undefined") module.exports = {promptKind: promptKind, promptLabel: promptLabel, isTouchCue: isTouchCue, failureMessage: failureMessage};

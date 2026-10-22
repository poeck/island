-- Opt in by loading this snippet. Replace existing conflicting bindings when adopting it.
-- Adopt this instead of an existing Super+Space bar binding when switching shells.
hl.bind("SUPER + Space", hl.dsp.exec_cmd("island bar toggle"))
hl.bind("SUPER + ALT + Space", hl.dsp.exec_cmd("island launcher toggle"))
hl.bind("SUPER + ALT + N", hl.dsp.exec_cmd("island notifications toggle"))
hl.bind("SUPER + ALT + Escape", hl.dsp.exec_cmd("island session toggle"))
-- This invokes the REAL locker, even while the island is in preview mode.
hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd("island lock --wait"))

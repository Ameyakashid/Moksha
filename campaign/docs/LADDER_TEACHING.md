# Contextual ladder controls

This is a presentation correction, not a traversal-controller change. In a fresh
screen-only Capacitor Mill playtest, the player let go while their feet remained
below the landing, then another attempt was interrupted by damage. Holding Up
finished the ascent. The existing controller deliberately releases on horizontal
input alone; it automatically settles onto a matching top platform when Up is
held through the end. Jump is not required for that supported exit.

The reference is MOKSHA's existing `combat_pc/player.gd` climb contract and
`combat_pc/tests/climb_regression.gd` supported-top/side-release tests, with the
established detached HUD presentation boundary. No commercial algorithm, code,
assets, input changes or physics constants are introduced. A separate staged
Mill-geometry probe exercised the real production player, ladder and platform:
16 checks each at actual 60 and 120 physics Hz passed. That is mechanical
evidence, not human usability or exact replay of the native recording.

`campaign.gd` reads current grip, target validity, room ownership, local overlap,
health and lifecycle into one `ladder_attached` HUD fact. It has no authority to
attach, move, release, save or alter sensory state. Pending room/retry, modals,
pause, death, hit/detach, invalid/moved/changed/queued targets clear the fact.
There is no history or distant endpoint query. Sight does not gate knowledge of
the player's own existing physical grip.

The HUD temporarily replaces only its existing left control strip with device-
specific continued-climb, release and jump instructions. Journal and pause stay
in their original positions; no toast obscures the enemy or ladder. All ordinary
footer wording remains unchanged when detached. The authored text is measured
against the actual 9-point font and available width in the focused contract.
Native appearance and ordinary-input acceptance remain separate work.

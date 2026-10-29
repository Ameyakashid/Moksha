# Proposed next module: Freight Lock

Status: implemented and tested in the bounded expanded demo. No duration claim.

## Actual action and consequence
A compact two-level freight room requires an intact physical crate to settle in a receiver before its shutter opens. The route cannot be completed by approaching an E marker. The player may fight through a listener/ranged lane, approach from a lift/ladder flank, or spend a spare ordinary crate to strike/distract an enemy before delivering the designated freight.

A successful receiver permanently latches the shutter and onward objective open. No redundant E relay, all-enemies-dead gate or repeated wave.

## Prototype before room authoring
Test a fixed launch cradle, approximately 140-pixel gap, receiving floor 30 pixels lower, and 140–160-pixel basin with a low entry lip and taller backstop. Dimensions are starting hypotheses, not verified trajectories. Existing props launch horizontally with lift, spin, bounce, and can break. Do not require pickup/carry, precision stacking or transport aboard a moving lift; these are not existing verified mechanics.

One detachable receiver uses an Area2D detector plus actual PhysicsBody2D basin contours. It accepts only an intact rigid prop that is supported inside and moving slowly; no airborne fly-through, player, enemy, bolt, Q pulse or E press can complete delivery. A short settling debounce removes jitter, not a timed waiting challenge. Permanently latch the route to avoid reclosing a pressure door on occupants.

At the cradle, E replaces only the designated freight crate, invalidating the previous one before spawning. Keep at most one live freight crate. Do not restore health, enemies or ordinary combat props. Disable replacement after success. R continues to retry the whole area. Test loss, destruction, overshoot, pause during flight, repeated replacement, death and reload.

## Sight and readability
Same physical route and objective in both sight states. Real launch/contact/receiver/shutter noises reveal their actual origins. The basin needs genuine collision contours because Area2D alone is excluded by the sonar collector. HUD status communicates missing/seated freight without requiring color or sound. Keep the ladder alternative to the optional lift.

Historical design note: the original statement that sentry bolts ignore props no longer describes the current production configuration. Current outbound/reflected projectile mask43 includes cargo layer8, and contacted cargo can retire a projectile as an obstruction under the shared carrier contract. This document is retained as the earlier design record; the new freight journey does not depend on a cover claim or add a cover mechanic.

## Acceptance
- Real crate launch, landing, receiver latch and actual shutter passage through ordinary input at 60/120 Hz in both sight states.
- Direct and flank approaches possible; player-only and E-only traversal cannot finish.
- No duplicate freight, ghost contours, trapped actor, irreversible lost-crate state or free health reset.
- Fresh observation assesses cargo understanding, tactical choice and recovery without coaching. Keep active play, discovery, pauses and tool latency separate.
- Scope: one room, one receiver, local replacement/objective wiring, one freight shutter plus onward door, three ordinary enemies. Preserve player/combat/prop/sonar cores.

## Final implementation notes
The cargo interlock itself is the room objective; no redundant second E relay is required. The onward door checks the same permanent cargo latch. The tested launch uses receiver=cradle+(246,30), 160-pixel basin, 8-pixel entry lip and 68-pixel backstop. The backstop extends40 pixels rightward on the same StaticBody so the existing PC ledge pull-up has real support; its incoming cargo face is unchanged. Direct loading lane and upper ladder flank both use ordinary input. Receiver settling is 0.22 seconds, solely a stability debounce.

# Cistern journey — accepted geometry and composed checkpoint

This isolated candidate replaces only the Cistern data at index4; the stable area ID is `cistern`. It starts from the exact combined Warden ZIP SHA256 `767f2c52deeae283ab7444d9fa9c7361b23e061391eb5b020bdc1aba0765b642`. All original archive members were restored without filtering.

## Intent and scope

A 3,600px connected drainage approach, maintenance interchange and upper spillway replaces the previous 1,900px ascent. One existing flood-control objective and seven original enemy types/stats remain. Locations change to serve fixed-support threats; NPCs are not expected to board or plan around lifts. The exit remains at y−760. No forced combat clear, extra relay, waiting gate, wave, health inflation or motor/controller change.

The lower maintenance route rides an existing diagonal lift; a wall-side fixed route remains available. The interchange offers a second vertical lift or fixed steps. Each moving support has an independent stationary departure and destination, never a mandatory moving-to-moving transfer. Flood control opens a physical upper egress bridge; beyond it the exposed roof competes with a sheltered channel containing the optional cache and reconnecting ladders. Continuous ground plus actual fixed recovery ladders prevents missed landings becoming permanent traps.

## Current acceptance status

Final geometry module SHA256 `079919498c716074a912cb36feeaeb724eeaf06f98a8def3a993ebdde52507d8` passes16/16 raw-input routes: fixed/lift × roof/channel × retained/traded ×60/120. All reach actual onward transition with zero deaths/retries and2–4 guards surviving. Channel routes collect the cache; roof routes bypass it. Measured optimized routes take27.33–36.85 simulated active seconds, not human durations.

Both moving-support alternatives prove actual carriage and direct stationary docking onto the exact authored StaticPlatform collider (script, center and size), with support-transition receipts and explicit rejection of intervening grounded support. Diagonal support carries160.46–171.22px horizontally and133.46–136.97px upward; vertical support carries288.99–289.06px upward. Both destination decks now sit slightly below their lift apex for ordinary walk-off. No moving-to-moving transfer or mandatory raised-deck jump remains.

Independent lifecycle58checks/rate pass for this geometry with the baseline save-v3 host; the later merged save-v4 rerun also passes 58 checks per rate in the final 37-stage aggregate. Physical recovery05 matrix16/16 also passes: explicit late-phase missed boarding, lower/upper dock falls, and channel falls × both sight states ×60/120; actual floor contact, fixed-route reentry and onward transition, zero deaths/retries. The missed-phase test deliberately waits at the real dock until the lift is absent; this is labelled test setup, not a game waiting gate. Native engine clips also pass: lift-channel retained31.55active seconds (both exact decks; no intervening support), fixed-roof traded32.93active seconds (actual onward). Local still review confirms readable side decks/relay and actual blind ladder/roof contours, with natural near-black gaps between pulses. These are scripted-input sector-start captures, not human usability validation.

## Preserved iteration evidence

Initial tests proved carriage and eventual destination but were strengthened because intervening falls/recovery did not prove direct docking. Weaker receipts remain under `attempt01`, not final proof. Raised destinations and the first side-offset revision failed stronger direct-dock tests; attempts02/03 and matrix01 preserve those failures and sources. Lower side-deck geometry fixes the observed landing issue without changing motors/controllers. Matrix02 uses matched fixed rendering/physics rates and preserves all16 final reports.

Recovery harness attempts are separately retained. First waypoint insertion accidentally shifted lift-stage indices; another attempt had a parse error. A later upper fall landed on an intact cargo body; requesting down+jump through a solid box was an observer error, not proof of an unrecoverable level. The revised fall input chooses a clear lateral descent corridor. These runs do not replace final recovery evidence.

## Evidence boundary

Final acceptance requires all fixed/lift × roof/channel × retained/traded ×60/120 combinations; actual support identity/carriage and direct stationary docking; real flood-control activation, open-bridge crossing and onward transition; missed docking/falls and fixed recovery; lifecycle pause/death/retry/Continue; native retained and traded readability. Isolated traded routes use an explicit pre-clock fixture, not a real station interaction. Scripted input timing is diagnostic, not human duration evidence or a30minute campaign claim.

## Reproduction

Create `demo/evidence/` if absent from a clean ZIP before running diagnostic scripts. Use matching physics and fixed-render rates:

```
godot --headless --fixed-fps 60 --path MOKSHA --script res://demo/tests/cistern_journey_route.gd -- --scene=res://demo/tests/cistern_journey_review.tscn --approach=lift_channel --hz=60
```

Approaches: `fixed_roof`, `fixed_channel`, `lift_roof`, `lift_channel`. Add `--sacrifice` for labelled pre-clock traded sight; repeat at120 with both rate arguments changed. Recovery script `cistern_journey_recovery.gd` accepts `--recovery=missed_boarding|lower_dock|upper_dock|channel`; use `lift_channel` for the first three, `fixed_channel` for channel. Its copied graph helper changes only test navigation, never production support/motor behavior.

The evidence index and immutable attempt directories live outside the reusable source project under `campaign_cistern_work/`; parent integration owns full-campaign and save-migration acceptance.

## Composed save-v4 follow-through

Final composed save-v4 host passes fresh32/32 (16route +16recovery) in `campaign_cistern_final_routes`, with zero deaths/retries and zero drift across717 pinned source files. All prescribed fall, exact landing, fixed reentry and onward receipts are present. The additional second-missed-boarding fallback branch fires0times in final32 and remains explicitly unexercised; no physical proof is claimed for that branch. Its first recovery pass found a different second-lift arrival phase: the observer could miss boarding and keep jumping below the deck rather than return through the fixed route. Recovery-only planning now returns to the departure waypoint if below boarding reach and centers the actor using ordinary horizontal input on the actual vertical support. This changes test intent only. Whether the fallback branch actually fires is reported explicitly; an unexercised branch is not a physical proof.

A separate full-campaign failure was an observer hanging forever on a real displaced crate while navigation requested a lower destination. A minimal ordinary Down release physically exited that exact hang on the next frame and completed the full traded60Hz campaign with zero deaths/retries. The parent owns the generic test-helper integration and its full-campaign reruns; the production controller was not changed.

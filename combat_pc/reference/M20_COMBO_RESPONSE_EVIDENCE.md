# M20 combo input responsiveness audit

Read-only runtime/source audit, 2026-10-06, following the v23 review. This document proposes an original MOKSHA candidate; it does not certify an implementation or measured gameplay feel. No runtime or presentation files were changed by this audit.

## Finding and smallest coherent candidate

The existing three-move controller already has the required structure: distinct Slash, Backhand and Finisher profiles, one pending request, fresh-input identities, legal recovery commitment, independent reuse locks, per-strike contact identities and pause-safe input capture. The concrete responsiveness gaps are the admission policy, especially its rejection of every fresh tap while the Finisher is live. Replacing the controller or shortening every animation is unnecessary to address these gaps.

Use a separate candidate chain resource. Set Slash and Backhand's `followup_open_seconds` to zero, preserving all windup, active, recovery, pose, damage, movement and cancellation settings. Add an opt-in fresh-only restart window in the final 0.12 seconds of Finisher recovery. Admit at most one fresh request for the next episode's first step, and execute it only after full Finisher completion and ordinary gates allow it. The 0.12 seconds is authored candidate tuning, not a Dead Cells value. Keep the baseline resource and its existing M9/M10 expectations available unchanged.

This improves ongoing taps without creating a three-move macro: three very rapid presses while the single pending slot is occupied still cannot enqueue two future moves. Holding alone in Fresh mode still produces exactly one strike. A 0.12-second terminal window should catch sustained approximately 10 Hz taps with ordinary fixed-step sampling, but slower or irregular taps can miss it and restart on the next idle edge. Verify several input phases and cadences before describing the result as consistently responsive.

## Actual local behavior

Source locations refer to the inspected pre-M20 `player.gd`; use function names if later edits move line numbers.

| Observation | Actual code/configuration | Effect |
| --- | --- | --- |
| Early fresh taps are discarded | `_capture_attack_input`, approximately 2171–2223, rejects ages below the step opening; `melee_step.gd` defaults to 0.035 seconds | Slash and Backhand ignore a quick second tap before their opening. There is no pre-opening request that can wait for legal commitment |
| Capture precedes phase advancement | `_run_physics_tick` captures at approximately 372, handles pause at 405, advances queue at 452 and combat at 456 | Opening and closing classification uses the previous simulated age. With normal fixed steps and a new attack starting at age zero, the first capturable 0.035-second opening occurs about 66.7 ms after attack start at 60 Hz and 50 ms at 120 Hz. These are code-derived estimates, not runtime measurements |
| Terminal attacks have a blanket rejection | `_capture_attack_input` rejects `_chain_next_step < 0` as `chain_complete` before considering phase/window | Every extra tap throughout the Finisher's 0.12 windup + 0.10 active + 0.24 recovery is discarded, including a tap on a tick which subsequently finishes recovery. A held button then cannot supply a new fresh edge |
| Follow-up deadline is adequate for the unchanged light chain | `melee_chain.gd` has 0.22-second follow-up lifetime; Slash commits after 0.070 + 0.065 + 0.060 = 0.195 seconds; Backhand after 0.065 + 0.070 + 0.065 = 0.200 seconds | Ordinary early fresh input does not need a longer lifetime merely because opening moves to zero. Default commitment at 60/120 Hz remains within that budget |
| Deadline is enforced before commitment | `_advance_chain_clocks` decrements/clears expired requests before `_advance_melee` and `_arbitrate_input` | A request whose remaining time becomes zero on the same tick that a gate opens expires first. Avoid configuring a restart lifetime exactly equal to its longest wait. The existing 0.14-second starter buffer gives a 0.12-second restart window margin at 60/120 Hz |
| One pending request already bounds spam | `_capture_attack_input` rejects a second request as `queue_full`; it does not replace the first ID or refresh its deadline | Preserve this. Rejected presses must never turn into later Finisher or restart requests |
| Pause ordering is already correct | Fresh input and hold/release observation precede local hitpause return; queue, step, recovery and reuse clocks advance only on unpaused ticks | A tap/release entirely inside hitpause can be retained, then consumed once. Lengthening buffer wall time or moving ordinary clocks ahead of pause would regress this |
| Legal commitment remains distinct from admission | `_try_chain_attack` requires the expected chain/step, valid source/epoch, permissions, shield/reuse gates, and recovery beyond `followup_commit_recovery_seconds` | Accepting an early request must not interrupt a windup/active phase or change existing movement/cancel permissions |
| Active contact has explicit protection | `_advance_melee` preserves an unsampled active phase; active entry returns before skipping that phase; contact uses new attack serials and generation guards | Keep this while changing admission. No skipped hitbox, duplicate target effect or old sweep carried into the next strike |

The baseline tests intentionally enforce these policies: `combo_regression.gd::_queue_cases` tests early-window rejection, first-slot ownership, host-denied expiry and all-phase terminal rejection. `_native_chain_cases` checks a paused native tap. `held_regression.gd` additionally relies on rejected edges not changing an existing input-policy snapshot. Candidate coverage should extend these contracts without reinterpreting archived baseline results.

## Terminal restart ownership

This is the only candidate change needing controller work beyond resource tuning.

1. Make terminal restart opt-in and default off. Restrict it to Fresh mode so Held Repeat's existing 0.08-second restart delay and Held Charge's episode ownership do not change.
2. Determine the late window from the committed step's recovery phase and duration. For the current Finisher, the final 0.12 seconds begins at 0.12 seconds of its 0.24-second recovery, nominal total step age 0.34 seconds. Admission is still evaluated against the pre-advance phase/age, and the same-tick completion edge must be accepted when it was already inside this window.
3. Store one typed restart request with the physical input/request identity, source/configuration epoch, expected completed chain/strike and bounded remaining lifetime. Do not represent it as a follow-up step of the terminal chain or reuse an old strike identity. No synthetic request may use this Fresh path.
4. Preserve full Finisher recovery. `attack_finished` must occur before the next `attack_started`, with a different chain episode, attack serial and fresh input ID. Ordinary shield, reuse, action and external permissions still control admission after completion.
5. `_finish_melee_step` calls `_reset_chain(completed)`, which currently clears the pending slot. Any preservation must be limited to this request and this natural terminal completion. Revalidate after both observable completion/reset callbacks. Hurt, reset, configuration changes, forced ownership changes, disabled controls, explicit buffer clear and a newer replacement owner must prevent restoration. Never restore a copied pending dictionary simply because completion returned.
6. Preserve the ordinary bounded deadline through temporary denial and hitpause; discard it once expired. Do not promote a rejected early Finisher press later, refresh its lifetime from spam, or let an expired request resurrect in idle.

## Pinned Dead Cells source recheck

Current connector reads revalidated the actual bodies at commit `77c3ad263c4187ade6d048ba77bb61f79e6cec44`. **BODY** means a surviving nonempty implementation; **CALL** means a real dispatch into missing behavior; **DECL** means declaration, empty body or throw stub. The decompiled representation is not independently established runtime equivalence. No game source/assets are copied into MOKSHA.

| Source and identity | Usable body | Exact missing behavior relevant to this pass |
| --- | --- | --- |
| [Weapon][weapon], blob `5515da6ac74a18b7188d1670e3611c14168e58ac` | **BODY:** cycle getter 39–41, attack-speed accessors 48–56, charge-turn default 141–143. **CALL:** readiness delegates to current skill 136–138 | `anticipateNext`, `needButtonRelease`, `requireRelease` are fields at 14, 20–21. `_executeImpl` 122, `incrementCycle` 125, anticipation/prepare 178–185, `cancelChain` 248, updates 251–255 and cycle-loss setup 257 are empty. Early-combo query 146–148 and cycle-loss query 260–262 throw. No queue/window/restart scheduler is recovered |
| [HeroWeaponsManager][manager], blob `4d0481b00096601195e18ae3616630d253b9faf4` | **BODY/CALL:** 75–82 queries a charging weapon's `CannotInterrupt` affix; its selector is unavailable | Down/pressed queries 84–90, charge cancellation 147–149 and admission 157–159 throw. Anticipation cancel 133, weapon updates 151–155 and execute hook 161 are empty. No fresh-versus-held order, priority, next-request lifetime or finisher boundary is recovered |
| [OldSkill][old], blob `5790f28b83d361415972fdc2cbaf34c034d7415c` | **BODY:** cooldown default 128–130 returns true | Charge/cooldown/control-lock/animation fields 6–25 are separate concepts. Prepare 69, execute 73, interrupt 76, readiness 103, update 111 and animation callbacks are unavailable. `WeaponSkill` inherits this class at Weapon 275–285; no ordering can be imported from the different newer Skill class |
| [StartSword][start], blob `82c4b5eb70bd6dd151217d3da5e250aa9bcbbcd1` | Constructor delegates to base | Execute 9–11 throws; hit hook 13 is empty. The starter sword supplies no missing three-step sequence or timings |
| [BroadSword][broad], blob `ade798068e188c4f352c41c86e63c2e14973754c`; [DualDaggers][dual], blob `4d1fa1f48befe9243807b7d39880148684d4f44c` | **BODY/CALL:** each cycle setter 13–19 requests critical-feedback cleanup at zero and stores the cycle | Execute, cycle increment and hit hook are unavailable. Setter behavior does not establish combo count, next-input window, finish recovery or cycle reset timing |
| [SharedComboWeapon][shared], blob `f8d2e163081efd540abf51316fc8a37493fb0252` | **BODY:** setter 16–22 conditionally stores a shared cycle; 34–36 checks an owner cooldown key | Getter, increment, cancellation and cycle-loss setup are unavailable. Keep the numeric key uninterpreted; no retention duration follows |
| [WreckingBall][wreck], blob `dc23d48ea822b246293852b0c67a7743267fd8e0` | **BODY/CALL:** ammunition ownership/cleanup 18–36 and cycle setter 61–67 survive | Its early-combo override 79–81 also throws. It does not rescue the missing base early-combo predicate |
| [Controller][controller], blob `852957d8ca0f202ec28e4d25832f906e4c9dc2b3` | Lock setter and binding selector survive | Press timers/frame presses/release fields 36–39 exist, but down/pressed queries and input-update consumers are unavailable. Their names do not imply buffer size or duration |

Fresh indexed searches for `anticipateNext` and `canComboNextSkillEarly` returned only Weapon's field and Weapon/WreckingBall's missing predicates, with returned URLs matching the pin. This is bounded corroboration, not proof that hidden/dynamic behavior does not exist. Prior audit's missing `BaseMelee.hx` finding was not independently re-proven by downloading the complete tree in this pass.

The official [Update 23 notes][p23], re-opened in this pass, establish an optional hold-to-chain setting and a qualitative increase to Oven Axe's combo window in 23.6 (2021-03-25). They do not provide numeric buffering, ordinary sword cycle/restart rules, queue capacity or input priority. The notes also describe Oven Axe's repeatable last hit, a weapon-specific behavior that should not be generalized to this three-move chain.

**Unknown in Dead Cells:** fresh opening/expiry, replacement policy, queue capacity, early-chain readiness ordering, full Finisher recovery, restart window/cadence, held/fresh conflict behavior, exact clip/hit/commit times and pause interaction. All proposed M20 numbers and permissions remain original authored MOKSHA policy. No generic other-game source substitutes for these missing bodies.

## Candidate test contract

- At 60 and 120 Hz, a fresh second edge immediately after Slash/Backhand starts occupies one slot and commits once at the same earliest legal recovery boundary as baseline. Record pre-capture age and committed timestamps so one-tick sampling effects are visible.
- One held press in Fresh mode yields one strike. A rapid burst cannot produce a backlog: additional edges while full neither replace nor refresh the first request, and no rejected ID later commits. Continue taps around 60, 90, 100, 120, 150 and 200 ms cadence with phase offsets; report which restart edges are inside the window rather than assuming all rates are gap-free.
- Test just before, at and after terminal restart opening; final-recovery completion tick; first idle tick; and a press after a natural full chain reset. Only in-window fresh input gets the special restart. The Finisher keeps its full duration and all three poses; next Slash gets a new chain and strike identity.
- Test deadline equality, temporary denial and permanent denial; existing shield/reuse locks; expiry while idle; and a long paused interval. Zero remaining time must have one documented outcome. Use a restart lifetime with margin over its longest normal wait.
- Capture/release/repress inside hitpause. The first eligible identity survives once, the slot cannot grow or refresh, phase/recovery/reuse clocks freeze, and release cannot synthesize a future Fresh request.
- In `chain_input_queued`, `attack_finished` and `chain_reset` callbacks, force hurt/reset, disable input, clear buffers, replace chain/input resource, restore the same resource after replacement, install another owner, or free the actor. No preserved restart may revive stale intent or contact authority. Test synchronous host denial at completion separately from owner replacement.
- Confirm Held Repeat and Held Charge keep their prior behavior, especially Repeat's restart delay, release clearing, fresh-edge snapshot ownership and Charge's exclusive hold episode. Preserve baseline resource regression expectations.
- Verify target contact once per strike, fresh facing at the new strike with committed active facing unchanged, safe sweep reset, terrain occlusion and moving-support pause. Ground/air permission intersection, actual fall excursion, spent air-jump/roll budgets and soft/hard landing rules remain unchanged.

[weapon]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/Weapon.hx
[manager]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/hero/HeroWeaponsManager.hx
[old]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/skill/OldSkill.hx
[start]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/StartSword.hx
[broad]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/BroadSword.hx
[dual]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/DualDaggers.hx
[shared]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/dual/SharedComboWeapon.hx
[wreck]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/WreckingBall.hx
[controller]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/Controller.hx
[p23]: https://deadcells.com/patchnotes/23

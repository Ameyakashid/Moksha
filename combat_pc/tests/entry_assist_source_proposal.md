# Optional perceived-target facing: bounded PC proposal

Prepared 2026-10-04. **Proposal only, outside the frozen MOKSHA project.** No implementation, level, NPC, weapon database or additional perception system is requested by this document.

## Decision

**A small opt-in experiment is justified as the next aim-related functional step after the recovery snapshot is cleared.** It fills a concrete missing capability: a neutral-input attack cannot currently orient toward even a host-confirmed, nearby perceived opponent. Dead Cells' developer explicitly identifies combat auto-aim, and a surviving weapon body conditionally bypasses its aim routine by cycle. This is sufficient reason to test an optional facing helper, but it does not establish a defect in MOKSHA's current feel.

Keep the accepted manual baseline and its defaults intact. Use one optional passive-fixture demonstration to compare a neutral attack while facing away from the target, then let observed play and user feedback determine whether the feature should become a default. There is no reason to block the accepted checkpoint on this addition or claim that its current manual behavior is wrong.

The minimum first example applies assistance **once at the first fresh starter's windup entry**. Charged followups, held-derived repeats and later chain steps remain opted out. This avoids overwriting a direction deliberately chosen earlier in a charge or chain and avoids inventing a manual-intent-memory policy. Broader per-step assistance can wait for a concrete need.

## Evidence boundary

Pin: [N3rdL0rd/DeadCellsDecomp `77c3ad263c4187ade6d048ba77bb61f79e6cec44`][pin], identified as PC v35 / build `50edff4`. This proposal builds on [FACING_AIR_CONTROL_EVIDENCE.md](FACING_AIR_CONTROL_EVIDENCE.md); the four relevant files were rechecked at that exact pin.

| Evidence | What it supports | What it does not recover |
|---|---|---|
| **PRIMARY:** [Sébastien Bénard's GDC 2019 presentation, page 17][gdc], lists combat turnaround and auto-aim | Aiming assistance is part of the developer's control design | The input precedence, selection algorithm, query geometry, sample time or current v35 behavior |
| **BODY/CALL:** [ElbowBlades 21–27][elbow] returns false at cycle zero and otherwise delegates to base auto-aim | Aim execution can differ by weapon cycle; a per-step opt-in is a reasonable original interface | The Boolean's permission-versus-success meaning, whether later calls succeed, or any target choice |
| **DECL:** [Weapon 98–103, 160–176][weapon] has missing owner-turn, auto-aim, hit-eligibility and air-control behavior. Its charge-turn method returns true at 141–143 | Keep facing, aim, hit eligibility and movement permissions distinct | Automatic facing admission, ordering, latching, final permissions or airborne effects |
| **DECL:** [TargetHelper 20–106][targets] names area/distance/sight/front/untargetable/breakable filters and selection, all unavailable | Target filtering/selection is a separate interface family | Which filters ordinary melee uses, their order, nearest-target ranking, prop exclusion or occlusion policy |
| **DECL:** [Hero.shouldTurn 143–145][hero] is a stub | Actor-side turn authority has an explicit surface | The final decision or when the weapon may turn the actor |

**All selection, timing, perception, geometry and precedence rules below are authored MOKSHA policy.** In particular, excluding props and occluded/unperceived targets is the requested MOKSHA constraint, not recovered Dead Cells filtering.

The existing PC gives concrete integration evidence: `_update_facing` follows nonzero horizontal input only when input and weapon-turn permissions permit it; `_start_attack_instance` enters windup; windup-to-active captures current facing for the strike. Read-only actor snapshot: `c7c18b726210665df2304ff4aba190edda54816eaeb6fded1b44a63751f1987d`, lines 2090–2115, 2162–2166 and 2715–2725. No provider or auto-aim routine was found in the inspected PC scripts/resources.

The GDC PDF text was read. Its screenshot renderer failed; no timing or input trace was measured. No further broad reference search is needed to choose this bounded authored experiment.

## Minimum host/actor contract

### Host supplies one optional offer

A synchronous, read-only provider accepts a request for this actor, this new attack instance and this physics tick. It returns **no offer**, or one immutable offer with:

- A live target handle/identity and a finite current world-space aim anchor
- An explicit classification as an opposing combat target, with eligibility, current perception and unobstructed visibility attested by the host
- The matching request token and current sample tick

The host owns the meaning of opponent, current perception and obstruction. A damageable body or a physics overlap alone is insufficient. Props, unperceived targets, occluded targets and invalid/dead targets produce no offer. Missing fields or failed attestations also mean no offer. Shielded or invulnerable status is not automatically a universal exclusion: eventual damage reception is separate from the host's declared aiming eligibility.

The reusable actor does not inspect scene-wide enemies, infer perception from distance, read hidden targets or build a candidate catalogue. The provider returns at most one already approved target; the actor contains no ranking algorithm. For the first fixture there is only one candidate, so nearest-target or tie-breaking behavior is unnecessary.

Use a bounded authored query region. A minimal region is the union of the current starter's left- and right-facing contact-preview boxes at its present position. The host checks the candidate against it, and the actor rejects an aim anchor outside it. This point-in-preview rule is an original simplification, not recovered strike-zone math. It adds no speculative radius or pursuit range. An equal-horizontal-position anchor keeps current facing.

The provider's attestations are an integration contract. The actor can verify structure, identity validity and bounds; it cannot independently prove the host's perception claim. The representative host must visibly exercise those conditions rather than always returning true.

### Actor owns admission and direction

1. Complete normal action arbitration and establish an admitted, opted-in fresh starter windup. Queued input and rejected attacks do not query. The first fixture enables assistance only on this starter, not on derived repeats, charged followups, continuation steps or idle movement.
2. Apply current manual horizontal intent through the existing controller. **Any nonzero normalized horizontal intent vetoes assistance**, even if a turn gate would prevent that manual turn. Neutral means neutral input, not zero velocity; drift, recoil or carrier motion are not aim commands.
3. Check all effective turn gates: input enabled, main-action capability, external restriction and the newly admitted step's windup permission. If any denies turning, do not request or apply assistance. Assistance cannot grant movement or action permission.
4. Query the provider once and synchronously. No asynchronous callback, queued response, previous-frame offer, retained target or retry during that attack.
5. Before applying, verify the same actor reset/configuration/action/weapon generations, query token, attack instance and admitted windup still exist; input remains neutral; all turn gates remain open; target identity and attestations remain valid. If the provider reenters or changes relevant state, discard the offer. A matching echoed tick alone is not proof of freshness.
6. Apply only a left/right facing suggestion immediately, then discard the offer. Normal permitted manual input during the remaining windup still overrides it. A failed or absent offer leaves the existing facing untouched.

No target handle enters the hit/damage path. There is no auto-attack, homing, target-position snap, approach impulse, distance-dependent speed or attack-range extension. If an authored attack already moves forward, changing facing can change that existing motion's direction; this is a real observable consequence to compare, not a new approach-to-target rule. The fixture should use a stationary strike if it needs to isolate facing alone.

### Preserve the existing strike commitment

“Attack entry” here means **windup admission**. It is distinct from **active entry**, when the existing PC latches contact direction. Assistance does not perform an early contact-direction latch.

For M10 specifically, reaching charge readiness starts the ordinary Charged Thrust windup. Permitted manual turning continues there, and active entry captures the final direction. The earlier addendum's phrase “when the charged strike commits” means that active boundary, not charge completion. This proposal does not change it.

The first example opts Charged Thrust out of assistance entirely. Sampling there could undo a deliberate direction chosen during charging after the player releases horizontal input. Avoiding that behavior is more valuable than generalizing the feature before feedback.

After the entry suggestion, target movement, disappearance or a new occluder may make the attack miss. There is no tracking or automatic correction. Existing active contact, occlusion and sweep checks still decide actual hits. Neither an active strike nor its historical sweep is rotated toward a later target. Target presence never changes gravity, air steering, jump count or fall history.

## One representative passive fixture

Use **one stationary passive combat-target proxy** in the existing PC test setting, with no AI or new level. The host explicitly registers this proxy as an eligible perceived opponent. Reposition that same proxy for mirrored cases and use one existing solid obstacle for occlusion. Its test controls can revoke perception/eligibility or present it as a prop; those are variations of one fixture, not a target system.

| Comparison | Acceptance |
|---|---|
| Assistance off/on, actor facing away, neutral fresh starter | Off preserves current facing. On makes at most one entry suggestion toward the approved proxy. The target must still be hit through ordinary contact |
| Opposite manual input or closed turn gate | No suggestion overrides manual input or a denied gate |
| Perception off, occluded, prop, invalid identity, missing offer or outside region | No automatic turn; the host's rejection is inspectable |
| Equal X and mirrored positions | Equal X keeps facing; left/right cases mirror without a target-ranking algorithm |
| Manual turn during windup, then proxy moved during active | Permitted manual windup turn wins; active contact direction stays latched |
| Charge completion, held repeat or later chain step | No provider query in the initial representative |
| Reset, cancellation or configuration mutation inside provider | Offer is discarded, no old action restored, no nested query or extra strike |

Keep the diagnostic result small: request kind, query count, accepted/rejected reason, input direction, facing before/after and eventual strike direction. It should explain the control decision, not expose an unperceived target.

**Stopping point:** the one-fixture comparison demonstrates the optional entry suggestion and its vetoes while preserving the accepted baseline. Default enablement, multiple-target choice, charged-followup assistance and broader perception behavior should wait for actual feel feedback. Target-conditioned air physics remains out of scope.

[pin]: https://github.com/N3rdL0rd/DeadCellsDecomp/tree/77c3ad263c4187ade6d048ba77bb61f79e6cec44
[weapon]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/Weapon.hx#L98-L176
[elbow]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/ElbowBlades.hx#L21-L27
[targets]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/TargetHelper.hx#L20-L106
[hero]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx#L143-L145
[gdc]: https://media.gdcvault.com/gdc2019/presentations/Benard-Sebastian-DeepCells.pdf#page=17


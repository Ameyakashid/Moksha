# High-fall landing: evidence and authored policy

Dead Cells has a distinct high-fall stun response. Its [public Hero declaration](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx#L512-L536) separates falling-too-fast, landing, ground contact and land-stun operations, but their bodies are missing. [Entity](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/Entity.hx#L944-L946) exposes fall-height history without its consumer. These establish the behavior and integration points, not a recoverable threshold or reset formula.

The strongest specific rule is [official update 14.6](https://deadcells.com/patchnotes/14): a roll started before impact during a still-active stomp can prevent high-fall stun, and that protection lasts only for the roll. An ordinary air roll, an expired stomp and an expired/canceled roll do not inherit that specific protection. This is distinct from ordinary damage invulnerability. The old roll-landing helper's horizontal addition of 0.2 and the unexplained no-cancel ratio 0.25 provide no landing duration.

## MOKSHA's optional rule

The host can opt into high-fall recovery independently from the reusable actor's movement abilities. Its first authored defaults require both a 220 px fall excursion and 400 px/s downward relative impact speed. A short impact/recovery owner, finite braking, a clearance-safe small body and buffered next actions make the result explicit. Exact parameters and the final transition policy are recorded in `../MOTOR_CONTRACT.md` and `MOKSHA_PARAMETER_LEDGER.json`; none is presented as extracted Dead Cells tuning.

Fall history is independent from jump/roll/dive budgets. Genuine support and accepted jumps define new excursions. An ordinary roll, weapon phase, dive startup or hurt reaction does not silently erase a long fall. Established support transport is not free-fall travel. A physical landing dispatches once, replenishes resources once and chooses one recovery owner and dominant landing sound event. High dive contact still emits its actual dive impact, while its high-fall recovery cannot stack a second movement driver over the first.

Only an accepted roll from active dive descent receives the narrowly scoped protection token. The descent-only choice is an authored interpretation of the historical active-stomp condition. Protection ends with that roll, including cancellation, and does not extend i-frames. Other legitimate mitigation, such as an accepted air jump beginning a new excursion, remains a separate rule.

The inspection course compares high and low drops on the same PC. It must also exercise requests before impact, through the finite recovery and at release; real moving/removed supports; ordinary versus dive-derived impact; and protection just before/at/after roll expiry. Poses remain original wireframe work. No fall damage, fatal-fall respawn, save rule or progression system is added by this pass.

## Unresolved reference details

The original height/speed test, duration scaling, fall-history reset matrix, recovery cancel priorities and landing animation tables remain unavailable. No current hard-landing footage was quantitatively measured. [Motion Twin's 2018 player guide](https://blog.playstation.com/2018/07/10/dead-cells-invades-ps4-august-7-6-tips-for-surviving/) describes broad roll cancelability, but it does not establish the later build's action-specific exceptions. This pass keeps the existing MOKSHA roll cancel windows; it does not relabel them as recovered rules.

[Update 35's landing fix](https://deadcells.com/patchnotes/) for Wings of the Crow is useful evidence that special movement must still dispatch real ground contact. It is a regression lesson, not a request to add that power. The current PC remains focused on MOKSHA's connected movement and combat foundation.

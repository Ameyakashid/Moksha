# Notice-aware objective captions

A sight-retained, screenshot-controlled Inundated Market run on c9772b0 exposed a real presentation overlap: the flood-key completion toast covered its world caption, and remained over another route caption during the descent. This fix changes presentation only. The run collected the key but ended in defeat; it did not establish a full level clear or human-paced combat balance.

## Responsibility boundary

The HUD view owns its currently painted notice rectangle, derived from the same measured layout used to draw it. Its existing owner forwards that detached geometry. Objective captions retain responsibility for their complete text block and painted-object exclusion. They now avoid both their own object and the actual notice, rather than pretending every toast makes the entire header taller.

The existing pinned reference mapping in `REFERENCE_FOUNDATION.txt` separates owned HUD parts and derived world presentation. It grounds this responsibility boundary, not the rectangle-placement algorithm: this finite candidate search is original MOKSHA code, not recovered commercial UI code.

The source object must still be on-screen before any caption relocation. A deterministic search tries whole-block placements around occupied edges/corners; it never moves individual lines independently. Every accepted rectangle stays inside the header/footer-safe viewport and outside all exclusions with padding. If no location fits, the caption is hidden rather than overlapped. An absent, empty, modal or overridden notice contributes no exclusion. No-notice placement retains the prior path exactly. Blind-hidden world presentation remains authoritative.

No player/controller, camera, collision, enemy, layout, objective, save, audio or timing authority is changed. This does not solve every possible HUD/world-art overlap or inter-caption collision.

## Verification

`campaign/quality/nov12_notice_caption/contract.gd` checks the reproduced overlap negative, current/wrapped/disappearing notices, translated/scaled HUD geometry, viewport edges, object-plus-notice obstruction, dense/no-space cases, source-object culling, modal retirement and the original no-notice placement. Inherited caption-safe, authored-side-hint, campaign presentation and scent contracts are also run. The receipt records exact log hashes.

Run with isolated HOME/XDG roots:

    godot --headless --editor --import --quit --path <project>
    godot --headless --path <project> --script res://campaign/quality/nov12_notice_caption/contract.gd

The first new test script had a local variable type-inference parse error. That failed QA attempt was preserved and rejected; adding an explicit boolean annotation fixed the fixture, not production code. Native verification of this revision remains separate from the source contracts.

## Other findings, deliberately not patched here

- The first ladder’s top is aligned with its platform. Inspected footage shows the operator’s feet still below the deck before horizontal release, followed by a later successful ascent. That does not establish a ladder sensor or controller defect. A more explicit visual dismount affordance can be evaluated separately without changing release authority.
- In the high-platform descent, the landing floor is outside the view at movie time 72.5 seconds; by 73 seconds the actor has reached the active floor arc and lost 8 HP. The camera’s falling-foot window can leave only 19–47 logical pixels below the feet before the control bar. This motivates a separate bounded falling-lookahead/fair-landing review, not an untested camera or collision change here.
- Market-specific inhabited details and physical-cargo versus usable-cache art remain separate readability work. No new interaction is implied for ordinary cargo.

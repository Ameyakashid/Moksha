# Primary visual reference observations

Inspected2026-10-04 through the cloud browser after the article's embedded media loaded. This adds actual visual evidence to the earlier textual audit. No reference artwork is included in the game or deliverable.

Source: Thomas Vasseur,24 January2018, [Art Design Deep Dive](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-).

## Running example

The article's embedded `8_Move.gif` was served as an animated WebP:35 encoded frames,500×208,40ms per encoded frame. Those are properties of this article's media, not proof of the game's render or physics tick rate. No controlled input or exact game-build identifier accompanies it.

Visible features across sampled frames0,3,6,…33:

- Alternating high knee recovery and extended leg reach clearly distinguish contact from recovery
- Arms pump in opposition to the legs, with forearms and shoulders helping the silhouette read
- The torso and head remain relatively steady with a forward lead while the legs cycle
- Trailing cloth reinforces the direction and speed
- The background scrolls; this is a running example, not an isolated measurement of root speed

The original MOKSHA wireframe was reviewed against these principles at actual game scale. Its34px body, joints, stride lengths, pose keys and timing remain authored MOKSHA values. This media does not establish braking, reversal, jumping, mantle or collision timing.

## Attack example for the next pass

The article's `4_AttackAnim.gif` was served as an animated WebP:45 encoded frames,430×214, first frame30ms and subsequent frames40ms. It visibly separates hammer wind-up, stretched commitment, low impact/follow-through, recovery and the next swing. Strong pose changes and weapon effects make the strikes readable. This is a qualitative reference for coupled attack poses; it does not reveal exact active hitboxes, cancellation windows, input timing or invulnerability.

Raw reference media and inspection strips are kept outside the game package. The deliverable contains only these observations and source links.

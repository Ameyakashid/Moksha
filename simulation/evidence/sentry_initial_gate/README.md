# Preserved initial fixture failure

The first frozen full run and an independent copy exposed a nondeterministic
cargo test: the test waited for target acquisition while its own cargo correctly
occluded sight, then used default random launch lift/spin. The test did not
actually establish a committed warning before claiming interruption.

The corrected fixture first observes real acquisition on a clear lane, inserts
an actual production mission crate during that warning, and uses explicit zero
launch lift/spin test tuning. A fresh ordinary sword input then launches it;
Godot still owns the full sweep, collision, Health receipt and interruption.
The corrected assertions require one real launch, one Health3 debit and no shot.
No production physical rule, mission layout, test tolerance or success condition
was relaxed. The old fixture and failed output are retained here.

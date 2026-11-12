Checkpoint disk-ownership extraction

campaign/save/checkpoint_store.gd now owns checkpoint reads, invalid-byte backup
verification and pending-file/rename commits. The campaign host keeps its public
facade methods, UI feedback, live-state application and result-export behavior.
No format version, key order, backup naming, validation order or actor behavior
changed. Read returns the codec's detached validated envelope.

Reproduce with campaign/quality/nov12_domain_checks.py (isolated HOME/XDG).
10/10 stages passed on Godot4.6.3; zero source drift. Includes17 content/snapshot
assertions,8750 pure-policy checks,32 district smoke and live build/save feedback/
adversarial restore at60/120Hz. Disk failures, invalid saves, existing invalid
backup preservation and Continue are covered by the existing save fixtures.
Not a crash-durability proof, Windows filesystem test or manual gameplay review.

Remaining migration: live state still belongs to the host. A separate restore
transaction and level/district owner have NOT been introduced. The extraction
retains existing write semantics rather than claiming stronger durability.

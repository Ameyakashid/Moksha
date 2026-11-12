Phase1a: content catalog and detached persisted run snapshots

Reproduce: python campaign/quality/nov12_domain_checks.py --output /tmp/new-evidence-directory
The runner isolates HOME and XDG data/config/cache paths. Godot 4.6.3.

10/10 stages passed, zero source drift: import, 17 new content/snapshot contracts,
8750 pure build/save checks, 32 district instantiations, and live build/save
feedback/adversarial restore at 60 and 120 Hz. Negative controls independently
removed restore detachment and duplicate-ID rejection; both were detected, then
production sources were restored byte-for-byte.

Missing authored files now fail closed before actors/save handling; the runtime
error layer and diagnostic are tested through a missing-content host subclass.
Its rendered pixels were NOT reviewed. No source layout, original actor,
controller, damage or presentation module changed. JSON envelope keys/order,
version1 and Continue remain compatible. Content values compared recursively
against original five source definitions (resource identity by resource path).

Ownership remains incremental: host still owns live run values, file I/O and
transition application. Snapshot capture owns only detached persisted values;
codec validates before returning detached data. Full store/restore-plan and
level-runtime extraction remain later steps, not claimed complete here.

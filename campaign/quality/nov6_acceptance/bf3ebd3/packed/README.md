# bf3 runtime: exact-source packed rehearsal

Source and packaging tools: c489885befb2264bf2dc0afd2cac8e147d1c9730.
Runtime freeze: bf3ebd382eb9485eeaffcdff9fe9bfcfda8d3ad5.
Actual tested PCK SHA-256:
490c51da2cb17b2d026d55af6e1739914837ae5e2fcefa0aac9fc861c08b04fa.

All 30 exact-source rehearsal stages passed with no fixture overlays. This includes
213 controller-device checks at each of 60/120 Hz, the prior controller/input,
release/lifecycle/audio/damage/save/journal stages, title/resource audit, and wrapper
smoke. Every external fixture equals its frozen Git blob. Production resources
were loaded from the PCK in an empty resource working directory.

The rehearsal-only Windows ZIP was CRC/hash verified and extracted into a fresh
directory. Its extracted PCK passed the resource audit on Linux, giving 31 accepted
stages including archive verification. The original official Windows executable
hash was preserved, but no Windows process was executed. Delivered guide links and
source/delivered guide hashes were checked. The ZIP is not a final delivery.

The source-root output-guard negative fixture passes 37 checks. All 16 frozen
packaging unit tests pass. The intentional duplicate-member warning is a negative
test, not a packaging failure. The three earlier audio output-guard corrections
are now committed, not overlays. Earlier failed and aborted attempts remain in
the b2e7f35 evidence directory and original rehearsal folders; nothing is replaced.
The separate 7db fallback remains unchanged.

This is a compact, self-contained evidence copy, not a playable package. PCK/EXE
binaries, archives, isolated saves, and import caches are intentionally excluded.
Raw reports and logs retain historical absolute paths. COPY_RECEIPT.json maps them
to these local copies. The parent rehearsal's native-review/ references map to
../native/; its external receipt directory maps to audio-json-receipts/. All file
identities are covered by EVIDENCE_INDEX.json and SHA256SUMS.

The adjacent native/ evidence covers 31 controlled visual fixtures. Ordinary native
keyboard/Alt-F4 testing is separate; a clean controlled capture does not establish
clean ordinary shutdown, audible output, target hardware speed, physical controller
support, native Windows operation, human traversal, or human completion time.

Run `python3 verify_evidence.py` to verify both evidence folders, exact fixture
hashes, accepted result/log pairs, the archive-audit receipt, and all 31 PNGs.
The final source/evidence freeze and final delivery artifacts are still separate.

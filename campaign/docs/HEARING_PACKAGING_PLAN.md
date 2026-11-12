# Hearing/camera packed verification

This tool-only extension preserves the previous 41 release checks and adds six
external contracts: sensory schema/store, seeded host transaction, perception,
load boundary, offer/Exchange copy, and camera trajectories. No export or Windows
execution is established by the Python unit tests.

The five hearing scripts run once at their authored default cadence, each in a
fresh HOME/XDG environment. The host fixture additionally gets a fresh external
store directory. Their bare JSON receipts must be unique, successful, contain
positive integer check counts and no failures. Nonzero exits and engine errors
still fail independently. No render-rate flag is misrepresented as physics rate.
The camera contract integrates 60 and 120 Hz trajectories internally.

QA scripts remain excluded from the PCK. The camera contract alone has its exact
baseline preload changed to a copied external sibling; original, adapted and
baseline hashes are reported. Production camera resources still load from the
PCK. The six checks precede archive creation, so public BUILD_REPORT includes
them. Full verification includes the existing post-archive fresh extraction check.

Generated START_HERE describes v3 envelopes, preserved v1/v2 backups, older-build
incompatibility, single-writer limits and the optional hearing choice. Historical
completion records remain immutable. The hearing slice guide is included; source
reference links are adapted using the existing checked guide mechanism. Full
source/history contains historical synthetic QA saves, not a claim that every
JSON file is absent. Windows runtime selection excludes user checkpoints/history.

Unit validation: package_nov6_tests.py (23), package_nov6_source_split_tests.py
(11), package_hearing_tests.py (5). Initial unit run exposed two stale guide/version
expectations, corrected without dropping tests. An initial invocation of the
engine-based audio guard helper lacked its required output argument and did not
run; it is not counted as a unit or packed pass. Logs are retained externally in
moksha-hearing-packaging-qa. Actual export, packed checks and restore/hash checks
must run only after final source acceptance and authorization.

Packed host fixture correction: `res://` globalizes to an empty string when the
project lives only in a PCK. An empty string is not a filesystem ancestor. The
fixture now applies the project-prefix rejection only for a nonempty resource
root; absolute-path and fresh/nonexisting-file-or-directory guards remain. Five
location regression assertions run alongside all existing host checks. Original
a32 packaging stopped at this guard before producing an archive; it is retained
as failed evidence, not counted as a completed build.

Integrated foundation verification, November 12, 2026

Production source tested: a517f460fae76c67e5eb2ef1da353fa73b0ec406
Combined original-code module boundaries, PC launcher/documentation and objective caption fix.

All 10 isolated stages in summary.json passed with no tracked source drift.
The runner imported assets, tested content validation/detachment and pure build policies,
loaded all 32 districts, then ran live build/save-feedback/adversarial save fixtures
at 60 and 120 Hz. The additional objective paint contract passed 151 checks.
The Windows launcher structural contract passed 2 tests; Windows execution was not run.

Reproduce:
  python3 campaign/quality/nov12_domain_checks.py --output <fresh-directory-outside-source>
  python3 tools/pc_startup_contract_test.py
  godot --headless --path . --script res://campaign/presentation/tests/objective_paint_contract.gd

Run any save tests with their isolation guard; the Python runner supplies isolated HOME/XDG.
These are focused integration gates, not a full new campaign playthrough, native Windows
acceptance, human pacing validation or evidence of the pending arcology/layout changes.
Original actor/controller/simulation files remain unchanged.

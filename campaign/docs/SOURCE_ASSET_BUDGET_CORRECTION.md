# Explicit Market source-budget correction

The original Market material (introduced at fb996cdaacabe323683d1aa24dbe1c18c2f9674f) was correctly included in packed resource checks, but its source-budget allowance was omitted. Both source 891 and release 596 exceed the old inventory and individual-file budgets. This predates the new Memory frontage atlas.

The Windows 596 release's 62 stages passed: import/export plus 45 packed executions and 15 supplemental packed executions. The packed asset checks (2,576 checks) established imported resources, hashes and exclusions, not source budget compliance. Those real passes remain valid; source-budget compliance was not established by that release. This correction does not claim Windows execution or target hardware performance.

The policy now adds exactly 3,188,709 inventory bytes for the reviewed Market asset, keeping all prior headroom and the separate Memory allowance. Combined inventory cap: 29,105,140 bytes. The ordinary individual-file cap remains 2,574,384 bytes. Only the exact Market path, SHA256 and size is exempt from that individual cap; absence or changed bytes fails closed. Baseline is not rebased. See campaign/assets/market/PROVENANCE.txt for original generation provenance.

The maintained tools/package_nov6.py now runs a separate frozen-source Python budget gate before import/export. Future counts must include this additional stage rather than re-label historical 62-stage receipts. No production assets or gameplay changed for this correction.

# L2/L3 final isolated input validation

**24/24 accepted runs.** Overall: PASS.

Post-health-rebind production.12 districts ×2 actual sight fixtures,60Hz. Each starts in an explicitly selected district; these are not a continuous campaign or human-duration measurement.

| District | Retained bot seconds | Traded bot seconds |
|---|---:|---:|
| l2_capacitor_mill | 33.75 | 28.42 |
| l2_exchange | 26.77 | 22.95 |
| l2_freight | 30.58 | 29.32 |
| l2_stamping_galleries | 33.65 | 25.52 |
| l2_thermal_foundry | 56.80 | 34.78 |
| l2_union_dispatch | 31.07 | 25.85 |
| l3_cistern | 40.97 | 37.18 |
| l3_drainage_commons | 43.63 | 37.10 |
| l3_homes | 37.10 | 28.57 |
| l3_inundated_market | 28.43 | 26.68 |
| l3_refuge_terraces | 30.97 | 29.37 |
| l3_water_clinic | 40.52 | 35.05 |

All reported accepted runs have no in-run source drift, no failures and matching current captured code/resource hashes. The manifest includes the executing observer and inherited navigation plus production scripts/scenes/resources. No exclusions are applied.

The retained/traded timings above belong only to these knowledgeable isolated bots. They must not be multiplied into a human playtime claim or added together as evidence of a continuous campaign.

Historical diagnostics, including the embedded Dispatch terminal failure and pre-health-rebind survival-invalidated results, remain under `../diagnostics/`.

## Later test-only maintenance (2026-10-29)

The 'matching current' statement above describes the accepted batch's capture time. After that batch, two **unexecuted historical fixture files** received narrow roster-count corrections: `simulation/tests/sentry_regression.gd`13→20 and `simulation/tests/listener_regression.gd`13→21, with matching wording. Independent untouched-baseline reproduction and exact diff review are recorded in `campaign/qa_audit/test_only_maintenance_manifest.json`. No production resource or this route's executing observer/ancestor changed. Raw accepted reports and their original broad manifests are preserved; the later clean continuous-campaign matrix and72-stage foundation use the corrected final source.


## Later rendered-review revision

This directory preserves acceptance of the earlier post-damage-fix source snapshot. The final9e22722 build subsequently changes presentation, panel input/guidance and authored text; these older hashes are not claimed to match that revision. Current full32-district route results are `campaign/tests/full_route_matrix.json` and `build_lens_matrix.json`, with exact source hashes in each report. Do not rerun this historical summary and interpret later-source mismatch as a physics regression, or relabel the old records as current.

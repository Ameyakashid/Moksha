# Frozen November 12 release validation

Runtime commit: `fe9936a2ecfde8a727ac2131801f3b9b22929d61`.
These are receipts gathered after that source freeze. This evidence-only commit
does not alter the delivered game. JSON copies normalize executor-local paths to
`$WORKSPACE`, `$PYTHON` and `$GODOT`; `MANIFEST.json` records both original and
archived hashes. Those placeholders are provenance, not runnable commands.

## Results

- `source-gate.json`: 20/20 source regression stages passed, no tracked drift.
- `package-gate.json`: 31/31 export/packed-runtime verification stages passed.
  The actual Windows ZIP's PCK was extracted and exercised by Linux Godot.
  **The Windows executable itself has not been run on Windows.**
- `neutral-public/`: normal-title, neutral, retained sight, public-record ending;
  all 32 districts, five natural level receipts, zero deaths/failures. Active
  automated time 1,352.05 seconds. Real Clinic roof and powered shortcut proof.
- `strength-blind-local/`: normal-title, Strength, actual optional sight trade,
  local-custody ending; all 32 districts, five natural level receipts, zero
  deaths/failures. Active automated time 1,196.98 seconds. Both whole-campaign
  runs used 60 Hz, clean exit code 0 and unchanged tracked source/observer.
- `footage/`: continuous Level 1 recording, 347.27 seconds including its menu
  hold, split into six consecutive clips; four separate 30-second checkpoint-
  start excerpts from Levels 2–5. Normal automated inputs drive real physics.
  These are not manual human play or a continuous filmed full campaign.

The earlier package report's `complete_campaign_playthrough: false` correctly
records that packaging alone did not prove it. The later independent campaign
receipts supply that additional evidence. Neither report rewrites the other.

## Reproduce the full campaign checks

Use an exact, clean checkout of the runtime commit and Godot 4.6.3 on PATH.
Keep these runner/observer files together and put output outside that checkout:

```sh
python3 neutral-public/run_full.py --source /path/to/frozen-checkout \
  --commit fe9936a2ecfde8a727ac2131801f3b9b22929d61 --output /path/to/new-output
```

The complementary runner supports `--lens=strength --sight=traded
--ending=local_custody`; see its `--help` for the exact interface. It seeds no
in-play position, health, objective or completion state. It may take more than
20 minutes on the original shared Linux environment. Do not run these while
playing in the same data directory; runners isolate their user-data folders.

## Limits

A successful scripted route does not certify every optional branch or novice
experience. Human pacing, audible mix, physical controller hardware and native
Windows behavior remain unverified. The requested 15–20 minutes per level is
still a design target, not an observed result. The campaign is a playable
five-level prototype; later locations remain visually less developed than the
new opening. Full commercial polish and the broader story/sense-trade vision
are not claimed complete.

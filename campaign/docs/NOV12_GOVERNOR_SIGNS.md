# Governor sign clarification

Based on frozen45a6c2b, not a geometry or campaign expansion.

- Hub: `AUTHORITY < / SUPPLY >`, moved from(2490,250) to(2350,250).
- West: `AUTHORITY < / STRIKE` at unchanged(1700,45).

The mandatory west authority breaker is at(1230,25); the optional bypass tool is farther west at(650,80). Naming the optional tool as the main west destination obscured route purpose. The strike wording is device-neutral. Existing dynamic interaction captions own input-button labels. This is an original clarity application of the pinned Dead Cells purpose-of-space principle, not borrowed map geometry or evidence of player confusion.

Native staged baseline capture confirmed an additional real overlap between the original central sign and THE EXCHANGE label. Moving only the sign140world units west removes that overlap. Candidate hub and west frames were visually inspected. These fixtures place the actor and stop enemies: they are presentation evidence, not a gameplay route. Both native processes exited0 but emitted cleanup resource-leak warnings; they are NOT clean-engine-exit acceptance. Raw logs and screenshots are preserved externally. No assertion of all-resolution or controller-session testing.

The bounded input observer uses an explicit initial Governor district fixture. It then opens the actual station with E and chooses retained/traded sight with ordinary menu keys. Measured navigation uses ordinary movement/combat/interact inputs, with live enemies and no position/health/objective/AI writes. The observer orders its own target list, not the host goal list. The four cases cover west-first/east-first × retained/traded, requiring exactly authority,supply,governor or supply,authority,governor; optional bypass and tool roll must remain uncollected. This is not normal-title full-campaign proof or human pacing evidence.

`check_content.py PROJECT_ROOT` reverses exactly the two permitted sign replacements and compares the entire Level5 source to its pinned45a6c2b SHA256. Thus objectives, dependencies, IDs, geometry, ladders, enemy content and everything else in that file remain identical. Other production files are unchanged in the commit. Static layout support separately passes32districts,123objectives,250enemy placements.

Reproduction: fresh isolated HOME/XDG paths, Godot4.6.3, `godot --headless --fixed-fps 60 --path PROJECT --script ABSOLUTE_ROUTE_GD -- --report=FRESH_EXTERNAL_JSON`, adding `--east-first` and/or `--blind`. Report parent must already exist; source paths/overwrites are rejected by the existing report sink. Require exit0, no ERROR/SCRIPT ERROR/leak warnings, parsed passed=true, exact goal order, requested sight, empty failures/drift and matching source/observer hashes. Historical baseline west-retained passed before production edit; never relabel its hashes as candidate.

Observer development: initial parser check rejected mixed indentation and then an unnecessarily duplicated inherited member. Both were fixed before any route started. Initial editor import lacked isolated XDG and reported settings-path errors; corrected isolated import succeeded. Failed attempt logs remain external, not acceptance evidence.

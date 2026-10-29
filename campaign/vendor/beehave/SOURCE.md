# Beehave blackboard

Upstream: https://github.com/bitbrain/beehave

Commit: `f09fdbdd489435c32989fed75b3d02ac69be9100` (v2.9.2).

Original file: https://raw.githubusercontent.com/bitbrain/beehave/f09fdbdd489435c32989fed75b3d02ac69be9100/addons/beehave/blackboard.gd

License: MIT, copyright (c) 2023 bitbrain. Full upstream license retained in LICENSE.

Original source SHA-256: `e1b980ce875b611f5881d158c4cce4d61b92ce8f27e09101304e8014706c10b6`.

Changes: removed editor-only icon annotation; renamed global class to MokshaBlackboard to avoid collisions; added provenance comment. Explicit Variant annotations added to safe_key/safe_val for this project’s warnings-as-errors setting. No behavior changes.

Purpose: shared objective/build state in campaign runtime. This is one standalone utility, not the full behavior-tree addon.

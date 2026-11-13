# Windows package ead13af: post-build evidence

**Package source:** `ead13aff036b1686a5f04e7e93c933995e8914a6`.
**Gameplay/runtime:** `3d7786ba9cf253dd6eff2781a1c285d5deea4c75`.
The intervening commits change documentation only. This later documentation does
not rewrite the frozen build, its embedded README or its historical receipts.

## Exact archive

- `MOKSHA-Windows-x64-ead13af.zip`: **54,753,350 bytes**.
- ZIP SHA-256: `6eeaa9deb8d22f568fdbb9c1894e7a65975091da852514523d7fbd94cf3f9927`.
- PCK SHA-256: `8a2f400292fba2f65c758f790a506ca9c4ada018e5a7b60426cf85ee0b697f72`.
- Official EXE SHA-256: `91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6`.

The builder passed **47/47 checks**, comprising import/export and 45 packed
executions on Linux. This verifies the produced pack, not native Windows behavior.
The **seven supplemental checks also passed** against the actual PCK from an
empty loose-resource directory: assets (2,576 assertions), sensory (26 at each
rate), encounter (37 at each rate), and Market (168 at each rate), at 60/120 Hz.
These are headless synthetic checks, not native play or audible-mix approval.

**Timeout disclosure:** the first Market 120 Hz attempt reached the 300-second
wall limit, exit 124, without a fixture assertion/error or completed receipt.
That failure is preserved. One identical pack/fixture retry, with a 900-second
limit and fresh isolated output, passed all 168 assertions in 612.339 seconds.
The other six passing supplement cases were reused, not rerun. This is composed
acceptance, not a claim that every initial attempt passed.

## Play and preserve saves

Extract the complete archive into a new folder. Keep `MOKSHA.exe` and `MOKSHA.pck`
together, then launch the EXE or included command launcher. Do not run inside the
ZIP or mix parts from different builds. See [PC quickstart](PC_QUICKSTART.md).
The previous `23a5aa6` package remains historical, not silently upgraded.

Back up the whole save folder before switching builds. This runtime still uses
checkpoint envelope v3 and completion schema 2; no experimental smell-trade schema
or reward is included. Do not disable antivirus or security controls for an
unsigned executable. Native Windows execution and subjective audio mix remain
unverified; the full original MOKSHA vision is not complete.

Portable machine-readable facts: [release receipt](WINDOWS_EAD13AF_RELEASE.json).

## Four verified small parts

Each Part ZIP is below 18 MiB. Download all four from the same set and extract
each into the same new folder. Keep the digest-named `.part` files beside
`Assemble-MOKSHA.cmd`, then run it to verify/join/extract the archive. See
`CURRENT_RELEASE_START_HERE.txt` supplied in every part. If security policy blocks
the helper, do not weaken it; obtain the full ZIP or use a trusted join tool and
verify the complete archive hash. The helper has not been executed on Windows.

| Part ZIP | Bytes | SHA-256 |
|---|---:|---|
| `MOKSHA-Market-Irritant-ead13af-Windows-Part1-of4.zip` | 17831050 | `71552a9ffd19cd54508332c5a6f4b0dca8d58030427f62251bae437792348862` |
| `MOKSHA-Market-Irritant-ead13af-Windows-Part2-of4.zip` | 17829464 | `1242d6d2882ac37108c46df981e2478fab82b62788292ab002f094747291d8f7` |
| `MOKSHA-Market-Irritant-ead13af-Windows-Part3-of4.zip` | 17829464 | `59c72332d5a829080436b0cd6fd402060cd0668658d1d0b8b576aeaac65d2405` |
| `MOKSHA-Market-Irritant-ead13af-Windows-Part4-of4.zip` | 1279646 | `30f26113491dee6159253c487b3fd536cf589310d19fd0ed162d7585edc28fc1` |

Reassembly and full ZIP CRC/member verification passed. The original builder ZIP
is unchanged. Its embedded pre-build source docs may still say no new Windows
build existed; use the supplied current release note and BUILD_PROVENANCE.json
for this artifact. These post-build docs do not retroactively replace those bytes.

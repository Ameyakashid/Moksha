#!/usr/bin/env python3
"""Read-only verification of this portable acceptance evidence record."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parent

def sha(data):return hashlib.sha256(data).hexdigest()
index={}
for line in (ROOT/'SHA256SUMS').read_text().splitlines():
 digest,relative=line.split('  ',1)
 if len(digest)!=64 or relative in index:raise SystemExit('Invalid or duplicate SHA256SUMS entry: '+relative)
 path=Path(relative)
 if path.is_absolute() or '..' in path.parts:raise SystemExit('Unsafe evidence path: '+relative)
 index[relative]=digest
actual={str(p.relative_to(ROOT)) for p in ROOT.rglob('*') if p.is_file() and p!=ROOT/'SHA256SUMS'}
if actual!=set(index):raise SystemExit('Evidence inventory mismatch: '+str(sorted(actual^set(index))))
for relative,digest in index.items():
 if sha((ROOT/relative).read_bytes())!=digest:raise SystemExit('File digest mismatch: '+relative)
logs=json.loads((ROOT/'evidence-sha256.json').read_text())
if len(logs)!=137:raise SystemExit('Expected exactly 137 original indexed raw logs')
for relative,digest in logs.items():
 if sha((ROOT/relative).read_bytes())!=digest:raise SystemExit('Original log digest mismatch: '+relative)
receipt=json.loads((ROOT/'COPY_RECEIPT.json').read_text())
for relative,expected in receipt['source_files'].items():
 data=(ROOT/relative).read_bytes()
 if len(data)!=expected['bytes'] or sha(data)!=expected['sha256']:raise SystemExit('Copied original mismatch: '+relative)
members=json.loads((ROOT/'replay-trace-members.json').read_text())
with zipfile.ZipFile(ROOT/members['archive']) as archive:
 if len(archive.namelist())!=18 or set(archive.namelist())!=set(members['members']):raise SystemExit('Trace member inventory mismatch')
 for relative,expected in members['members'].items():
  data=archive.read(relative)
  if len(data)!=expected['bytes'] or sha(data)!=expected['sha256']:raise SystemExit('Trace member mismatch: '+relative)
print(f"PASS: {len(index)} indexed files, {len(logs)} original raw logs, {len(receipt['source_files'])} copied originals, and 18 exact trace members")

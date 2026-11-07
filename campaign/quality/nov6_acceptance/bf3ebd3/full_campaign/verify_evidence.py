#!/usr/bin/env python3
"""Verify the compact evidence and every losslessly archived raw report/log."""
from pathlib import Path
import hashlib, json, tarfile
root=Path(__file__).resolve().parent
for line in (root/'SHA256SUMS').read_text().splitlines():
    expected,name=line.split('  ',1)
    path=root/name
    if hashlib.sha256(path.read_bytes()).hexdigest()!=expected:
        raise SystemExit('SHA-256 mismatch: '+name)
expected=json.loads((root/'raw_member_sha256.json').read_text())
with tarfile.open(root/'raw_reports_and_logs.tar.gz','r:gz') as archive:
    members=archive.getmembers()
    if {m.name for m in members}!=set(expected):
        raise SystemExit('Unexpected or missing raw archive member')
    for member in members:
        if not member.isfile() or member.name.startswith('/') or '..' in Path(member.name).parts:
            raise SystemExit('Unsafe archive member: '+member.name)
        actual=hashlib.sha256(archive.extractfile(member).read()).hexdigest()
        if actual!=expected[member.name]:raise SystemExit('Raw member SHA-256 mismatch: '+member.name)
summary=json.loads((root/'matrix_summary.json').read_text())
print('BUNDLE_INTEGRITY_PASS raw_members='+str(len(expected))+' matrix_passed='+str(summary['passed']))

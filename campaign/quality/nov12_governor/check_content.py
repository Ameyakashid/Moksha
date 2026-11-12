"""Exact-byte protection of authored Governor content except two allowed signs."""
import hashlib, pathlib, sys
root=pathlib.Path(sys.argv[1])
p=root/'campaign/layouts/level_05.gd'
s=p.read_text()
assert s.count('Vector2(2350,250),"AUTHORITY < / SUPPLY >"')==1
assert s.count('"AUTHORITY < / STRIKE"')==1
restored=s.replace('Vector2(2350,250),"AUTHORITY < / SUPPLY >"','Vector2(2490,250),"BYPASS < / GOVERNOR / SUPPLY >"').replace('"AUTHORITY < / STRIKE"','"WEST BYPASS <"')
assert hashlib.sha256(restored.encode()).hexdigest()=='01a3f16004e6374a2e3999a8129b4912d1904f8fcc7d162e1406546b3c3abaad'
print('GOVERNOR_PROTECTED_CONTENT PASS: all non-sign content byte-identical to45a6c2b')

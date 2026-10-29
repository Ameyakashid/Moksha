#!/usr/bin/env python3
"""Build a portable source ZIP, excluding captures, caches and generated evidence.

Run from any directory. --output stages a candidate without replacing a delivery.
Runnable tests and readable acceptance reports stay; generated JSON and per-tick
evidence are delivered separately in companion verification archives.
"""
from pathlib import Path
import argparse
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=root/'delivery/MOKSHA-Two-Level-Project.zip')
output = parser.parse_args().output.resolve()
output.parent.mkdir(parents=True, exist_ok=True)
temporary = output.with_suffix('.building.zip')
excluded_roots = {'art_sources', 'delivery', 'pc'}
excluded_parts = {'.godot', '.git', '__pycache__', 'logs', 'm5_provisional_e772'}
files = []
with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(root.rglob('*')):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if relative.parts[0] in excluded_roots or excluded_parts.intersection(relative.parts):
            continue
        if path.suffix in {'.zip', '.log', '.import', '.pyc'} or path.name == 'package-results.json':
            continue
        # Large historical machine-readable audit ships unchanged in the M21
        # companion evidence. Runtime, runnable tests and readable source map stay.
        if relative == Path('combat_pc/reference/FUNCTION_COVERAGE.json'):
            continue
        if relative.parts[:2] == ('combat_pc', 'tests') and (path.suffix == '.json' or path.name.endswith(('.json.gz', '.gd.txt'))):
            continue
        if relative.parent == Path('combat_pc') and path.name.endswith('verification.json'):
            continue
        if relative.parts[:3] in {('combat_pc', 'visuals', 'tests'), ('combat_pc', 'components', 'tests')} and path.suffix in {'.png', '.jpg', '.jpeg', '.gif', '.mp4', '.webm', '.json'}:
            continue
        archive.write(path, Path('MOKSHA')/relative)
        files.append(str(relative))
with zipfile.ZipFile(temporary) as archive:
    assert archive.testzip() is None, 'ZIP CRC check failed'
    for relative in files:
        assert archive.read('MOKSHA/'+relative) == (root/relative).read_bytes(), 'Source changed during packaging: '+relative
assert temporary.stat().st_size < 10_000_000, 'Delivery exceeds the 10 MB project budget'
temporary.replace(output)
report = {'filename': output.name, 'bytes': output.stat().st_size, 'files': len(files),
          'sha256': hashlib.sha256(output.read_bytes()).hexdigest(), 'crc_verified': True}
(output.parent/'package-results.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report))

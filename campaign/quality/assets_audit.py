#!/usr/bin/env python3
"""Conservative source/runtime inventory, not export/download size or GPU memory.

All runtime suffixes outside named development directories are included, even
unreachable legacy assets. No Git dependency: also works in extracted archives.
Only literal load/preload and serialized resource paths can be statically checked;
dynamic paths need the engine smoke check. Imported cache paths are excluded.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import struct
import wave

ROOT = Path(__file__).resolve().parents[2]
EXCLUDED = {'.git', '.godot', '__pycache__', 'tests', 'enemy_tests', 'qa_audit',
            'route_tests', 'route_tests_45', 'evidence', 'docs', 'quality',
            'history', 'export_templates'}
SUFFIXES = {'.gd', '.tscn', '.tres', '.gdshader', '.png', '.jpg', '.jpeg',
            '.webp', '.ogg', '.wav', '.ttf', '.otf'}
TEXT = {'.gd', '.tscn', '.tres', '.gdshader'}
REFERENCES = re.compile(r'\b(?:load|preload)\(\s*["\'](res://[^"\']+)["\']\s*\)')
SERIALIZED_REFERENCES = re.compile(r'(?:\bpath|run/main_scene)\s*=\s*["\'](res://[^"\']+)["\']')


def inventory(root):
    rows, errors, references = [], [], []
    for path in sorted(root.rglob('*')):
        rel = path.relative_to(root)
        if not path.is_file() or EXCLUDED.intersection(rel.parts):
            continue
        if path.suffix not in SUFFIXES and path.name != 'project.godot':
            continue
        data = path.read_bytes()
        row = {'path': rel.as_posix(), 'bytes': len(data),
               'sha256': hashlib.sha256(data).hexdigest()}
        if path.suffix == '.png':
            if len(data) < 24 or data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
                errors.append(f'{rel}: invalid PNG header')
            else:
                w, h = struct.unpack('>II', data[16:24])
                row.update(width=w, height=h, pixels=w*h)
                if not w or not h:
                    errors.append(f'{rel}: zero PNG dimension')
        if path.suffix == '.wav':
            try:
                with wave.open(str(path), 'rb') as wav:
                    row['audio'] = {'channels': wav.getnchannels(),
                                    'sample_width_bytes': wav.getsampwidth(),
                                    'sample_rate': wav.getframerate(),
                                    'frames': wav.getnframes(),
                                    'seconds': wav.getnframes()/wav.getframerate()}
                    expected = wav.getnframes()*wav.getnchannels()*wav.getsampwidth()
                    if len(wav.readframes(wav.getnframes())) != expected:
                        errors.append(f'{rel}: truncated WAV payload')
            except (wave.Error, EOFError, ZeroDivisionError):
                errors.append(f'{rel}: invalid WAV')
        if path.suffix in TEXT or path.name == 'project.godot':
            source = data.decode('utf-8')
            for ref in REFERENCES.findall(source) + SERIALIZED_REFERENCES.findall(source):
                target = ref.removeprefix('res://')
                references.append({'source': str(rel), 'target': target})
                if '..' in Path(target).parts or not (root/target).is_file():
                    errors.append(f'{rel}: missing/unsafe literal resource {ref}')
        rows.append(row)
    metrics = {'inventory_bytes': sum(r['bytes'] for r in rows),
               'file_count': len(rows),
               'largest_file_bytes': max((r['bytes'] for r in rows), default=0),
               'largest_png_pixels': max((r.get('pixels', 0) for r in rows), default=0),
               'wav_pcm_bytes': sum(r['audio']['frames']*r['audio']['channels']*r['audio']['sample_width_bytes'] for r in rows if 'audio' in r)}
    return {'metrics': metrics, 'files': rows, 'literal_references_checked': len(references),
            'errors': errors}

def audit(root, budgets):
    report = inventory(root)
    for name, limit in budgets['limits'].items():
        measured = report['metrics'][name]
        if measured > limit:
            report['errors'].append(f'Budget {name}: {measured} > {limit}')
    report.update(passed=not report['errors'], budgets=budgets,
                  scope='Conservative source/runtime inventory, including legacy assets; not exported size, FPS, GPU memory, or full dynamic dependency resolution.',
                  excluded_directory_names=sorted(EXCLUDED))
    return report

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--budgets', type=Path, default=Path(__file__).with_name('assets_budgets.json'))
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = audit(args.root, json.loads(args.budgets.read_text()))
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'files'}, indent=2))
    return 0 if report['passed'] else 1

if __name__ == '__main__':
    raise SystemExit(main())

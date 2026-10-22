#!/usr/bin/env python3
"""Render packaged Inter without system fonts; compare real glyphs, not QFont claims."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/typography'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path, help='Built Island package, e.g. result')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='island-typography-') as directory:
        base = Path(directory)
        source = base / 'source'
        shutil.copytree(args.package.resolve() / 'share/island/src' if args.package else ROOT / 'src', source)
        # Nix-store directory modes survive copytree; allow adding the fixture.
        source.chmod(0o700)
        shutil.copy(ROOT / 'tests/native/typography.qml', source / 'typography.qml')
        empty = base / 'empty-fonts'; empty.mkdir()
        cache = base / 'cache'; cache.mkdir()
        # A dev shell exposes Inter's installed named instances and used to
        # mask the bug. Force Qt to use only the face registered by FontLoader.
        config = base / 'fonts.conf'
        config.write_text(f'<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd"><fontconfig><dir>{empty}</dir><cachedir>{cache}</cachedir></fontconfig>')
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                   FONTCONFIG_FILE=str(config), QT_QPA_PLATFORMTHEME='', QS_DISABLE_CRASH_HANDLER='1',
                   XDG_CACHE_HOME=str(cache), XDG_CONFIG_HOME=str(base), XDG_RUNTIME_DIR=str(base))
        if args.package: env.pop('ISLAND_FONT', None)
        qs = env.get('ISLAND_QUICKSHELL') or shutil.which('quickshell')
        assert qs, 'Run in nix develop'
        reports = []
        for scale in [1, 1.25, 1.6]:
            image = OUT / f'{round(scale * 100)}-weights.png'
            result = subprocess.run([qs, '-p', str(source / 'typography.qml')], env=dict(env,
                                    QT_SCALE_FACTOR=str(scale), ISLAND_TYPOGRAPHY_IMAGE=str(image)),
                                    text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15)
            (OUT / f'{round(scale * 100)}.log').write_text(result.stdout)
            assert result.returncode == 0, result.stdout
            assert not any(s in result.stdout for s in ['Binding loop', 'ReferenceError', 'TypeError', 'Unable to assign', 'Failed to load configuration']), result.stdout
            report = json.loads(next(line.split('TYPOGRAPHY_REPORT ', 1)[1] for line in result.stdout.splitlines() if 'TYPOGRAPHY_REPORT ' in line))
            assert report['loaded'], report
            for sample in report['samples']:
                assert sample['family'] == 'Inter Variable', sample
                assert sample['axis'] == sample['weight'], sample
            assert next(s for s in report['samples'] if s['name'] == 'dynamic')['axis'] == 600, report
            # FontInfo can claim 500/600 while rendering Regular. Compare each
            # shared Label's actual glyphs with an explicit-axis Qt reference.
            width = round(920 * scale); height = round(620 * scale)
            raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(image), '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'])
            assert len(raw) == width * height * 3
            def crop(x, y, w, h):
                return b''.join(raw[(row * width + x) * 3:(row * width + x + w) * 3] for row in range(y, y + h))
            signatures = []
            for index in range(4):
                left = crop(round(24*scale), round((60+48*index)*scale), round(400*scale), round(48*scale))
                reference = crop(round(464*scale), round((60+48*index)*scale), round(400*scale), round(48*scale))
                assert left == reference, f'{scale}: weight {400+index*100} differs from its axis reference'
                signatures.append(hashlib.sha256(left).hexdigest())
            assert len(set(signatures)) == 4, f'{scale}: weights rendered identically'
            reports.append(dict(scale=scale, **report, glyphHashes=signatures))
        (OUT / 'report.json').write_text(json.dumps(reports, indent=2))
    print('Packaged Inter: real 400/500/600/700 glyphs, controls, dynamic weights and 100/125/160% rendering passed')


if __name__ == '__main__':
    main()

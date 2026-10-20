"""Build the web app (docs/07 §12): `flutter build web` with the release flags, then shell.json,
the list of files the service worker caches so the app opens offline.

    python3 tool/web/build_web.py                 # -> build/web
    python3 tool/web/build_web.py --no-build      # only rewrite build/web/shell.json

CanvasKit is bundled (--no-web-resources-cdn) so nothing is fetched from Google at run time.
shell.json leaves out what the app never loads: the Wasm renderers (skwasm, wimp: the build is dart2js), symbol files,
Flutter's deprecated service worker, the host files, and the data the app caches itself.
Standalone, stdlib only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / 'build' / 'web'

SKIP_DIRS = {'canvaskit/webparagraph'}
SKIP_FILES = {'flutter_service_worker.js', 'shell.json', 'sw.js', '_headers', 'robots.txt', '404.html'}
SKIP_PREFIXES = ('canvaskit/skwasm', 'canvaskit/wimp')
SKIP_SUFFIXES = ('.symbols',)


def shell_files() -> list[str]:
    out = []
    for dirpath, dirs, files in os.walk(WEB):
        rel_dir = Path(dirpath).relative_to(WEB).as_posix()
        dirs[:] = sorted(d for d in dirs if (f'{rel_dir}/{d}' if rel_dir != '.' else d) not in SKIP_DIRS)
        for name in sorted(files):
            rel = name if rel_dir == '.' else f'{rel_dir}/{name}'
            if name in SKIP_FILES or rel.startswith(SKIP_PREFIXES) or name.endswith(SKIP_SUFFIXES):
                continue
            out.append(rel)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--no-build', action='store_true', help='keep build/web, only write shell.json')
    ap.add_argument('--dart-define', action='append', default=[], metavar='KEY=VALUE')
    a = ap.parse_args()
    if not a.no_build:
        flutter = shutil.which('flutter') or shutil.which('flutter.bat')
        if not flutter:
            raise SystemExit('flutter is not on PATH')
        cmd = [flutter, 'build', 'web', '--release', '--no-web-resources-cdn', '--no-wasm-dry-run'] + [f'--dart-define={d}' for d in a.dart_define]
        r = subprocess.run(cmd, cwd=ROOT)
        if r.returncode:
            return r.returncode
    if not (WEB / 'index.html').is_file():
        raise SystemExit(f'{WEB} has no build')
    files = ['./'] + shell_files()
    (WEB / 'shell.json').write_text(json.dumps(files, indent=0) + '\n', encoding='utf-8')
    size = sum((WEB / f).stat().st_size for f in files[1:])
    # The build version the service worker is keyed by: Flutter's token no longer changes between
    # builds (its deprecated worker has no resource list), so hash the shell files ourselves.
    boot = WEB / 'flutter_bootstrap.js'
    version_line = re.compile(r'const buildVersion = .*?;\n', re.S)
    h = hashlib.sha256()
    for f in files[1:]:
        h.update(f.encode())
        # The bootstrap is hashed without the line this very step writes, so a rerun on the same
        # build gives the same version.
        h.update(version_line.sub('', boot.read_text(encoding='utf-8')).encode() if WEB / f == boot else (WEB / f).read_bytes())
    version = h.hexdigest()[:12]
    text, n = version_line.subn(f'const buildVersion = "{version}";\n', boot.read_text(encoding='utf-8'), count=1)
    if n != 1:
        raise SystemExit('flutter_bootstrap.js has no buildVersion line (web/flutter_bootstrap.js changed?)')
    boot.write_text(text, encoding='utf-8')
    print(f'{WEB.relative_to(ROOT)}/shell.json: {len(files)} files, {size / 2**20:.1f} MB to cache for offline use; build {version}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

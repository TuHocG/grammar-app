"""Assemble the site for Cloudflare Pages (docs/07 §12): the web app (build/web) plus the data
(build/host), and a second copy marked "do not index" for the preview deployment.

    python3 tool/web/build_web.py && python3 tool/content/bundle.py --host     # the two inputs
    python3 tool/web/build_site.py                                            # -> build/site, build/site-preview
    python3 tool/web/build_site.py --live https://grammar4.pages.dev          # also keep the data version live there

With --live, the version the live site serves is kept next to the new one (its manifest, packs
and pictures are fetched from there and checked against the manifest), so an app that loaded the
old manifest before the deploy still finds everything. The free host allows 20,000 files and
25 MiB per file; both are checked. Standalone, stdlib only.
"""
from __future__ import annotations

import argparse
import hashlib
import http.client
import json
import shutil
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / 'build' / 'web'
HOST = ROOT / 'build' / 'host'
SITE = ROOT / 'build' / 'site'
PREVIEW = ROOT / 'build' / 'site-preview'

NOINDEX_META = '  <meta name="robots" content="noindex, nofollow">\n'
NOINDEX_HEADERS = '\n# Preview deployment: keep it out of search engines.\n/*\n  X-Robots-Tag: noindex, nofollow\n'

FetchError = (urllib.error.URLError, http.client.HTTPException, ValueError, KeyError, TypeError, OSError)


def _fetch(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=120) as r:  # noqa: S310 (https URL from the command line)
        return r.read()


def keep_live_version(live: str, site: Path) -> None:
    """Copies the data version served at [live] into the site, unless it is the one being built.
    Everything is fetched and checked first; the old manifest is written last, so a failure
    half-way leaves nothing dangling (only a warning: the deploy still goes ahead)."""
    live = live.rstrip('/')
    try:
        latest = json.loads(_fetch(f'{live}/data/latest.json'))
        version, manifest_rel = latest['version'], latest['manifest']
        manifest_path = site / manifest_rel
        if manifest_path.exists():
            print(f'live version {version} is the one being built')
            return
        manifest = json.loads(_fetch(f'{live}/{manifest_rel}'))
        fetched = 0
        for pack in manifest['db']['packs']:
            dst = site / pack['name']
            if dst.exists():
                continue
            data = _fetch(f'{live}/{pack["name"]}')
            if len(data) != pack['size'] or hashlib.sha256(data).hexdigest() != pack['sha256']:
                raise ValueError(f'{pack["name"]} from {live} does not match its manifest')
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(data)
            fetched += 1
        pictures = 0
        for rel, (size, sha8) in manifest['images'].items():
            dst = site / rel
            if dst.exists() and dst.stat().st_size == size and hashlib.sha256(dst.read_bytes()).hexdigest()[:8] == sha8:
                continue  # the same picture, under the same path, in the new version
            data = _fetch(f'{live}/{rel}?v={sha8}')
            if len(data) != size or hashlib.sha256(data).hexdigest()[:8] != sha8:
                raise ValueError(f'{rel} from {live} does not match its manifest')
            if dst.exists():
                # A different picture under the same path: the old manifest's clients ask for it with
                # the old hash in the query, but the host serves one file per path. Keep the new one.
                continue
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(data)
            pictures += 1
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
        print(f'kept live version {version}: manifest, {fetched} packs and {pictures} pictures fetched')
    except FetchError as e:
        print(f'warning: could not keep the live version from {live} ({e}); only the new one is served', file=sys.stderr)


def check_limits(site: Path) -> None:
    files = [p for p in site.rglob('*') if p.is_file()]
    big = [p for p in files if p.stat().st_size > 25 * 1024 * 1024]
    if big:
        raise SystemExit(f'{len(big)} file(s) over 25 MiB: {[str(p.relative_to(site)) for p in big[:3]]}')
    if len(files) >= 20000:
        raise SystemExit(f'{len(files)} files: the free host allows 20,000')
    print(f'{site.relative_to(ROOT)}/: {len(files)} files, {sum(p.stat().st_size for p in files) / 2**20:.1f} MB')


def make_preview(site: Path, preview: Path) -> None:
    """The same site, told to stay out of search engines."""
    shutil.rmtree(preview, ignore_errors=True)
    shutil.copytree(site, preview)
    (preview / 'robots.txt').write_text('User-agent: *\nDisallow: /\n', encoding='utf-8')
    (preview / 'sitemap.xml').unlink(missing_ok=True)
    index = preview / 'index.html'
    text = index.read_text(encoding='utf-8')
    if NOINDEX_META not in text:
        index.write_text(text.replace('<meta charset="UTF-8">\n', '<meta charset="UTF-8">\n' + NOINDEX_META, 1), encoding='utf-8')
    headers = preview / '_headers'
    headers.write_text(headers.read_text(encoding='utf-8') + NOINDEX_HEADERS, encoding='utf-8')


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--live', metavar='URL', help='the production site, whose data version is kept alongside')
    ap.add_argument('--out', type=Path, default=SITE)
    ap.add_argument('--preview', type=Path, default=PREVIEW)
    a = ap.parse_args()
    for d, hint in ((WEB, 'tool/web/build_web.py'), (HOST, 'tool/content/bundle.py --host')):
        if not d.is_dir():
            raise SystemExit(f'{d} is missing: run python3 {hint}')
    if not (WEB / 'shell.json').is_file():
        raise SystemExit('build/web/shell.json is missing: build with python3 tool/web/build_web.py')
    site: Path = a.out
    shutil.rmtree(site, ignore_errors=True)
    shutil.copytree(WEB, site, ignore=shutil.ignore_patterns('flutter_service_worker.js'))
    shutil.copytree(HOST, site, dirs_exist_ok=True)
    if a.live:
        keep_live_version(a.live, site)
    check_limits(site)
    make_preview(site, a.preview)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

"""Package the content for users: grammar.db and grammar.images, two files to download side by side.

    python3 tool/content/bundle.py                      # pack, then build/content/grammar.db + grammar.images
    python3 tool/content/bundle.py --zip-data           # also grammar4-data-<version>.zip holding both, to share by hand
    python3 tool/content/bundle.py --zip-audio DIR      # also grammar4-audio-<version>.zip from DIR (1.mp3 …)
    python3 tool/content/bundle.py --no-pack-db         # reuse content/grammar.db as is
    python3 tool/content/bundle.py --web                # also build/content/web/: the web variant (see below)
    python3 tool/content/bundle.py --host               # --web, then tool/content/host.py -> build/host/ (the web host layout)

Users put both files in one folder, then pick that folder in Cài Đặt → Dữ liệu:

    grammar.db        lessons + the required Từ Vựng Tranh pages (table media)
    grammar.images    reading and Luyện Nói illustrations (optional: lessons work without them)

grammar.images is a zip holding `img/readings/…`, `img/dialogs/…` under their content paths, stored
uncompressed (WebP is already compressed) so the app reads each picture in place
(lib/data/image_pack.dart): one file to copy instead of thousands. Its own extension keeps users
from unzipping it. The release workflow attaches the two files as they are, plus grammar.db.gz (the
same database gzipped, a third of the size) and bundle.json (version, size and sha256 of each file), for
the in-app download planned in docs/07 §12; --zip-data adds one zip with grammar.db and grammar.images
(unzip into a folder, then pick it) for sharing by hand, like the audio zip.

The audio zip holds `audio/<n>.mp3`: unzip it into the same folder, next to grammar.db (or pick
the folder in Cài Đặt → Dữ liệu → Âm thanh thực). content/dataset/ is the repo's source layout only.
The content version goes into build/content/bundle.json and SHA256SUMS.txt.

--web writes build/content/web/: grammar.db of the `web` variant (pack.py --variant web: no media
table, no video subtitles) and img/pages/ with the Từ Vựng Tranh pages as files, since that database
does not embed them; the web host (docs/07 §12) serves both. Both variants are then packed from the
dataset in one go, so they describe the same content; without --web a stale build/content/web/ is removed.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import unicodedata
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / 'content'
OUT = ROOT / 'build' / 'content'


def _sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--no-pack-db', action='store_true', help='do not rebuild content/grammar.db first')
    ap.add_argument('--zip-data', action='store_true', help='also grammar4-data-<version>.zip with grammar.db and grammar.images')
    ap.add_argument('--zip-audio', type=Path, metavar='DIR', help='folder with the real-voice recordings (1.mp3, 2.mp3 …)')
    ap.add_argument('--web', action='store_true', help='also build/content/web/ (grammar.db of the web variant + img/pages/); repacks both variants')
    ap.add_argument('--host', action='store_true', help='--web, then host.py --verify: build/host/ for the web host (docs/09 §4)')
    a = ap.parse_args()
    if a.host:
        a.web = True

    pack_py = str(ROOT / 'tool' / 'content' / 'pack.py')
    web_dir = OUT / 'web'
    shutil.rmtree(web_dir, ignore_errors=True)
    if not a.no_pack_db or a.web:
        for tool in (str(ROOT / 'tool' / 'content' / 'check.py'), pack_py):
            r = subprocess.run([sys.executable, tool])
            if r.returncode:
                return r.returncode
    db = CONTENT / 'grammar.db'
    con = sqlite3.connect(f'file:{db}?mode=ro', uri=True)
    meta = dict(con.execute('SELECT key, value FROM meta').fetchall())
    embedded = {p for (p,) in con.execute('SELECT path FROM media')} if con.execute(
        "SELECT 1 FROM sqlite_master WHERE name = 'media'").fetchone() else set()
    con.close()
    version = meta.get('content_version') or 'dev'

    OUT.mkdir(parents=True, exist_ok=True)
    shipped_db = OUT / 'grammar.db'
    shipped_db.unlink(missing_ok=True)
    shutil.copyfile(db, shipped_db)
    gz = OUT / 'grammar.db.gz'
    # mtime=0: the same database gzips to the same bytes.
    with shipped_db.open('rb') as src, gzip.GzipFile(gz, 'wb', compresslevel=9, mtime=0) as dst:
        shutil.copyfileobj(src, dst, 1 << 20)
    outputs: list[Path] = [shipped_db, gz]
    img_root = CONTENT / 'dataset' / 'img'
    images_zip = OUT / 'grammar.images'
    n_img = 0
    with zipfile.ZipFile(images_zip, 'w', zipfile.ZIP_STORED) as z:
        for dirpath, dirs, files in os.walk(img_root):
            dirs.sort()
            for name in sorted(files):
                full = Path(dirpath) / name
                # Content paths are NFC; some file systems hand names back decomposed.
                rel = unicodedata.normalize('NFC', 'img/' + full.relative_to(img_root).as_posix())
                if rel in embedded:
                    continue   # already inside grammar.db
                z.write(full, rel)
                n_img += 1
    outputs.append(images_zip)
    print(f'grammar.db: content {version}, schema {meta.get("schema_version")}, '
          f'{len(embedded)} pictures embedded; {images_zip.name}: {n_img} illustrations')

    if a.web:
        r = subprocess.run([sys.executable, pack_py, '--variant', 'web', '--out', str(web_dir / 'grammar.db')])
        if r.returncode:
            return r.returncode
        pages = sorted(embedded)
        for rel in pages:
            dst = web_dir / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(CONTENT / 'dataset' / rel, dst)
        print(f'{web_dir.relative_to(ROOT)}/: web variant + {len(pages)} pages as files')
    if a.host:
        r = subprocess.run([sys.executable, str(ROOT / 'tool' / 'content' / 'host.py'), '--verify'])
        if r.returncode:
            return r.returncode

    if a.zip_data:
        data_zip = OUT / f'grammar4-data-{version}.zip'
        with zipfile.ZipFile(data_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
            z.write(shipped_db, shipped_db.name)
            z.write(images_zip, images_zip.name, compress_type=zipfile.ZIP_STORED)   # WebP, already compressed
        outputs.append(data_zip)
        print(f'{data_zip.name}: grammar.db + {images_zip.name}')

    if a.zip_audio:
        audio_zip = OUT / f'grammar4-audio-{version}.zip'
        files = sorted(f for f in a.zip_audio.iterdir() if f.suffix.lower() in ('.mp3', '.wav'))
        with zipfile.ZipFile(audio_zip, 'w', zipfile.ZIP_STORED) as z:
            for f in files:
                z.write(f, f'audio/{f.name}')
        outputs.append(audio_zip)
        print(f'{audio_zip.name}: {len(files)} recordings in audio/')

    sums = OUT / 'SHA256SUMS.txt'
    lines = [f'{_sha256(p)}  {p.name}' for p in outputs]
    sums.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    for p, line in zip(outputs, lines):
        print(f'  {p.stat().st_size / 2**20:7.1f} MB  {line[:16]}…  {p.name}')
    (OUT / 'bundle.json').write_text(json.dumps({
        'content_version': version, 'schema_version': meta.get('schema_version'), 'content_date': meta.get('content_date'),
        'files': {p.name: {'bytes': p.stat().st_size, 'sha256': l.split()[0]} for p, l in zip(outputs, lines)},
    }, indent=1) + '\n', encoding='utf-8')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

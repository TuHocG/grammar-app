"""Package the content for users: one zip with grammar.db and grammar-images.zip side by side.

    python3 tool/content/bundle.py                      # pack, then build/content/grammar4-data-<version>.zip
    python3 tool/content/bundle.py --audio DIR          # also grammar4-audio-<version>.zip from DIR (1.mp3 …)
    python3 tool/content/bundle.py --no-pack            # reuse content/grammar.db as is
    GRAMMAR_DB_KEY=… python3 tool/content/bundle.py     # encrypt grammar.db (same key as the app build)

Layout inside the data zip (unzip anywhere, then pick that folder in Cài Đặt → Dữ liệu):

    grammar.db            lessons + the required Từ Vựng Tranh pages (table media)
    grammar-images.zip    reading and Luyện Nói illustrations (optional: lessons work without them)

grammar-images.zip holds `img/readings/…`, `img/dialogs/…` under their content paths, stored
uncompressed (WebP is already compressed) so the app reads each picture in place
(lib/data/image_pack.dart): one file to copy instead of thousands.

The audio zip holds `audio/<n>.mp3|wav`: unzip it into the same folder, next to grammar.db (or pick
the folder in Cài Đặt → Dữ liệu → Âm thanh thực). content/dataset/ is the repo's source layout only.
With a key (--key or env GRAMMAR_DB_KEY) the zipped grammar.db is encrypted with SQLite3MultipleCiphers
(tool/encrypt_db.dart, needs the Dart SDK); only an app built with the same --dart-define=GRAMMAR_DB_KEY
opens it. Outputs also a SHA-256 list (build/content/SHA256SUMS.txt).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
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
    ap.add_argument('--no-pack', action='store_true', help='do not rebuild content/grammar.db first')
    ap.add_argument('--audio', type=Path, help='folder with the real-voice recordings (1.mp3, 2.wav …)')
    ap.add_argument('--key', default=os.environ.get('GRAMMAR_DB_KEY', ''), help='encrypt grammar.db (default: env GRAMMAR_DB_KEY)')
    a = ap.parse_args()

    if not a.no_pack:
        for tool in ('check.py', 'pack.py'):
            r = subprocess.run([sys.executable, str(ROOT / 'tool' / 'content' / tool)])
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
    shipped_db = db
    if a.key:
        shipped_db = OUT / 'grammar.encrypted.db'
        dart = 'dart.bat' if os.name == 'nt' else 'dart'
        r = subprocess.run([dart, 'run', 'tool/encrypt_db.dart', str(db), str(shipped_db), a.key], cwd=ROOT)
        if r.returncode:
            print('encryption failed')
            return r.returncode
    outputs: list[Path] = []
    data_zip = OUT / f'grammar4-data-{version}.zip'
    img_root = CONTENT / 'dataset' / 'img'
    images_zip = OUT / 'grammar-images.zip'
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
    with zipfile.ZipFile(data_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        z.write(shipped_db, 'grammar.db')
        z.write(images_zip, images_zip.name, compress_type=zipfile.ZIP_STORED)
    outputs.append(data_zip)
    images_zip.unlink()
    if shipped_db != db:
        shipped_db.unlink()
    print(f'{data_zip.name}: grammar.db ({"encrypted, " if a.key else ""}content {version}, schema {meta.get("schema_version")}, '
          f'{len(embedded)} pictures embedded) + {images_zip.name} ({n_img} illustrations)')

    if a.audio:
        audio_zip = OUT / f'grammar4-audio-{version}.zip'
        files = sorted(f for f in a.audio.iterdir() if f.suffix.lower() in ('.mp3', '.wav'))
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
        'encrypted': bool(a.key),
        'files': {p.name: {'bytes': p.stat().st_size, 'sha256': l.split()[0]} for p, l in zip(outputs, lines)},
    }, indent=1) + '\n', encoding='utf-8')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

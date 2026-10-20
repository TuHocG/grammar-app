"""Lay out the web data (docs/07 §12) for a static host: the `web` grammar.db cut into compressed
blocks, the pictures as files, and a manifest the app reads.

    python3 tool/content/host.py                 # build/content/web/grammar.db -> build/host/
    python3 tool/content/host.py --verify        # also reassemble the database from the packs and compare
    python3 tool/content/host.py --block-size 32768 --pack-size 4

Output (build/host/):

    data/latest.json              {"version", "schema", "manifest"}: where the current manifest is
    data/<version>/manifest.json  how the database is cut up, sha256 of every pack, list of pictures
    data/db/<sha16>.bin           packs: raw-deflate blocks of the database, back to back; named by
                                  content (sha256 prefix) so they are immutable on the host
    img/...                       every picture under its content path (illustrations and the
                                  Từ Vựng Tranh pages, which the `web` database does not embed)

The app downloads the packs once and reads the database through a virtual file system that
inflates one block at a time (lib/data/block_vfs.dart), so only the block size matters for
speed: the default 64 KiB holds 16 SQLite pages. Packs are about `--pack-size` MiB so that a
download can resume per pack; Cloudflare Pages allows 25 MiB per file. Standalone, stdlib only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import unicodedata
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / 'content'
FORMAT = 1


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def deflate(block: bytes, level: int) -> bytes:
    """Raw deflate (no zlib header), what the app inflates with `ZLibDecoder(raw: true)`."""
    c = zlib.compressobj(level, zlib.DEFLATED, -15)
    return c.compress(block) + c.flush()


def pack_db(db: Path, out: Path, block_size: int, pack_bytes: int, level: int) -> dict:
    """Writes the packs under out/data/db/ and returns the `db` part of the manifest."""
    size = db.stat().st_size
    con = sqlite3.connect(db.resolve().as_uri() + '?mode=ro', uri=True)
    page_size = con.execute('PRAGMA page_size').fetchone()[0]
    con.close()
    if block_size % page_size:
        raise SystemExit(f'block size {block_size} is not a multiple of the page size {page_size}')
    packs: list[dict] = []
    cur_blocks: list[bytes] = []
    cur_len = 0

    def flush():
        nonlocal cur_blocks, cur_len
        if not cur_blocks:
            return
        data = b''.join(cur_blocks)
        name = f'data/db/{_sha256(data)[:16]}.bin'
        (out / name).parent.mkdir(parents=True, exist_ok=True)
        (out / name).write_bytes(data)
        packs.append({'name': name, 'size': len(data), 'sha256': _sha256(data), 'blocks': [len(b) for b in cur_blocks]})
        cur_blocks, cur_len = [], 0

    with db.open('rb') as f:
        while True:
            block = f.read(block_size)
            if not block:
                break
            z = deflate(block, level)
            if cur_len and cur_len + len(z) > pack_bytes:
                flush()
            cur_blocks.append(z)
            cur_len += len(z)
    flush()
    return {'size': size, 'sha256': _sha256_file(db), 'page_size': page_size, 'block_size': block_size, 'packs': packs}


def copy_images(img_root: Path, out: Path) -> dict[str, list]:
    """Copies img/** under out/img/ with NFC names (sorted by that name, so the order does not depend
    on the file system); returns {rel: [size, sha8]}. Dotfiles (.DS_Store) are left out."""
    files = {}
    for dirpath, dirs, names in os.walk(img_root):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for name in names:
            if name.startswith('.'):
                continue
            full = Path(dirpath) / name
            files[unicodedata.normalize('NFC', 'img/' + full.relative_to(img_root).as_posix())] = full
    images: dict[str, list] = {}
    for rel in sorted(files):
        dst = out / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(files[rel], dst)
        data = files[rel].read_bytes()
        images[rel] = [len(data), _sha256(data)[:8]]
    return images


def verify(out: Path) -> None:
    """Reads latest.json and the manifest back from disk, reassembles the database from the packs,
    checks every hash, the pictures and the limits of the free host (docs/09 §4)."""
    latest = json.loads((out / 'data' / 'latest.json').read_text(encoding='utf-8'))
    manifest = json.loads((out / latest['manifest']).read_text(encoding='utf-8'))
    if manifest['content_version'] != latest['version'] or manifest['schema'] != latest['schema']:
        raise SystemExit('latest.json and the manifest disagree')
    h = hashlib.sha256()
    total = 0
    for p in manifest['db']['packs']:
        data = (out / p['name']).read_bytes()
        if len(data) != p['size'] or _sha256(data) != p['sha256']:
            raise SystemExit(f'{p["name"]}: size or sha256 differs from the manifest')
        off = 0
        for n in p['blocks']:
            block = zlib.decompress(data[off:off + n], -15)
            h.update(block)
            total += len(block)
            off += n
        if off != len(data):
            raise SystemExit(f'{p["name"]}: {len(data) - off} bytes beyond the listed blocks')
    if total != manifest['db']['size'] or h.hexdigest() != manifest['db']['sha256']:
        raise SystemExit('the packs do not reassemble into the database')
    for rel, (size, sha8) in manifest['images'].items():
        f = out / rel
        if not f.is_file() or f.stat().st_size != size or _sha256_file(f)[:8] != sha8:
            raise SystemExit(f'{rel}: missing or different from the manifest')
    files = [p for p in out.rglob('*') if p.is_file()]
    big = [p for p in files if p.stat().st_size > 25 * 1024 * 1024]
    if big:
        raise SystemExit(f'{len(big)} file(s) over 25 MiB: {big[:3]}')
    if len(files) >= 20000:
        raise SystemExit(f'{len(files)} files: the free host allows 20,000')
    print(f'verified: {len(manifest["db"]["packs"])} packs reassemble the database, {len(manifest["images"])} pictures; {len(files)} files, all under 25 MiB')


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--src', type=Path, default=ROOT / 'build' / 'content' / 'web', help='folder with the web grammar.db (bundle.py --web)')
    ap.add_argument('--images', type=Path, default=CONTENT / 'dataset' / 'img', help='the pictures (img/**)')
    ap.add_argument('--out', type=Path, default=ROOT / 'build' / 'host')
    ap.add_argument('--block-size', type=int, default=64 * 1024, help='bytes per block, a multiple of the page size (default 64 KiB)')
    ap.add_argument('--pack-size', type=float, default=8, help='about this many MiB per pack (default 8)')
    ap.add_argument('--level', type=int, default=9, help='deflate level 1-9')
    ap.add_argument('--verify', action='store_true', help='reassemble from the packs and compare')
    a = ap.parse_args()

    db = a.src.resolve() / 'grammar.db'
    out: Path = a.out.resolve()
    if out in (ROOT, *ROOT.parents) or db.is_relative_to(out) or a.images.resolve().is_relative_to(out):
        raise SystemExit(f'refusing to empty {out}: it holds the source data')
    if not db.is_file():
        raise SystemExit(f'{db} is missing: run python3 tool/content/bundle.py --web first')
    con = sqlite3.connect(db.as_uri() + '?mode=ro', uri=True)
    meta = dict(con.execute('SELECT key, value FROM meta').fetchall())
    con.close()
    if meta.get('variant') != 'web':
        raise SystemExit(f'{db} is the {meta.get("variant")!r} variant; the host serves the web variant (pack.py --variant web)')
    version = meta['content_version']

    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    db_part = pack_db(db, out, a.block_size, int(a.pack_size * 1024 * 1024), a.level)
    images = copy_images(a.images, out)
    manifest = {
        'format': FORMAT,
        'content_version': version,
        'schema': int(meta['schema_version']),
        'date': meta.get('content_date', ''),
        'variant': 'web',
        'db': db_part,
        'images': images,
    }
    mdir = out / 'data' / version
    mdir.mkdir(parents=True)
    (mdir / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    (out / 'data' / 'latest.json').write_text(json.dumps({'version': version, 'schema': int(meta['schema_version']), 'manifest': f'data/{version}/manifest.json'}) + '\n', encoding='utf-8')
    packed = sum(p['size'] for p in db_part['packs'])
    shown = out.relative_to(ROOT) if out.is_relative_to(ROOT) else out
    print(f'{shown}/: content {version}, database {db_part["size"] / 2**20:.1f} MB -> {len(db_part["packs"])} packs, '
          f'{packed / 2**20:.1f} MB ({a.block_size // 1024} KiB blocks); {len(images)} pictures')
    if a.verify:
        verify(out)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

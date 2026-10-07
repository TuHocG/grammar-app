"""Pack content/dataset (JSON + media) into content/grammar.db, the read-only content DB of Grammar 4.0.

    python3 tool/content/pack.py                    # -> content/grammar.db (gitignored)
    python3 tool/content/pack.py --out some/where.db

Standalone (Python 3.11+, stdlib only). Schema: grammar4/docs/09. The content version and the
schema version come from content/content.json and are written into the `meta` table, where the app reads
them (`content_version`, `schema_version`).

Pictures the lessons cannot work without (the Từ Vựng Tranh pages: hotspots are drawn on them) are
embedded in the `media` table. Illustrations (readings, dialogs) and recordings stay files;
the DB keeps their relative paths (`img/readings/x.webp`, `audio/1.mp3`). In a release they sit in
`img/` and `audio/` next to grammar.db (tool/content/bundle.py); in the repo they are under content/dataset/.
"""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
import time
import unicodedata
from pathlib import Path

CONTENT = Path(__file__).resolve().parents[2] / 'content'


def search_key(headword: str) -> str:
    """Lookup key: lower-case, accents stripped, spaces collapsed (same as the app's searchKey)."""
    decomposed = unicodedata.normalize('NFD', headword.lower())
    base = ''.join(c for c in decomposed if not unicodedata.combining(c)).replace('\u0111', 'd')
    return re.sub(r'\s+', ' ', base).strip()

SCHEMA = """
PRAGMA page_size = 4096;
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
-- Required pictures, stored in the DB; looked up by the same relative path the content uses.
CREATE TABLE media (path TEXT PRIMARY KEY, mime TEXT NOT NULL, data BLOB NOT NULL);

CREATE TABLE dict_entry (
  id INTEGER PRIMARY KEY,          -- order in datatu.txt
  headword TEXT NOT NULL,
  key TEXT NOT NULL,               -- lower-case, accent-stripped search key
  ipa TEXT,
  segs TEXT NOT NULL,              -- JSON [{k,t,vi?}]
  quick TEXT,                      -- JSON {ipa,rs,pos,vi} or NULL
  redirect TEXT                    -- headword to show instead ("Xem#x#" entries), else NULL
);
CREATE INDEX dict_entry_key ON dict_entry(key);
CREATE VIRTUAL TABLE dict_fts USING fts5(headword, content='dict_entry', content_rowid='id', tokenize='unicode61');

CREATE TABLE quick_def (key TEXT PRIMARY KEY, word TEXT NOT NULL, ipa TEXT, respell TEXT, pos TEXT, vi TEXT NOT NULL);

CREATE TABLE reading_section (
  sid INTEGER PRIMARY KEY, parent_sid INTEGER, title TEXT NOT NULL, depth INTEGER NOT NULL, position INTEGER NOT NULL
);
CREATE TABLE reading (
  id INTEGER PRIMARY KEY,          -- record index in data.av
  sid INTEGER NOT NULL REFERENCES reading_section(sid),
  position INTEGER NOT NULL,
  title TEXT NOT NULL,
  img TEXT, audio TEXT, times TEXT, title_audio INTEGER NOT NULL DEFAULT 0, page TEXT,   -- times: JSON [start of each sentence..., end]
  en TEXT NOT NULL, vi TEXT NOT NULL             -- JSON [[sentence,...],...] (paragraphs)
);
CREATE INDEX reading_sid ON reading(sid, position);
CREATE TABLE reading_sentence (
  reading_id INTEGER NOT NULL REFERENCES reading(id),
  idx INTEGER NOT NULL,            -- 0-based across the whole reading
  para INTEGER NOT NULL,
  en TEXT NOT NULL, vi TEXT,
  PRIMARY KEY (reading_id, idx)
);
CREATE VIRTUAL TABLE reading_sentence_fts USING fts5(en, content='reading_sentence', tokenize='unicode61');

CREATE TABLE dialog_topic (sid INTEGER PRIMARY KEY, title TEXT NOT NULL, position INTEGER NOT NULL);
CREATE TABLE dialog (
  id INTEGER PRIMARY KEY, sid INTEGER NOT NULL REFERENCES dialog_topic(sid), position INTEGER NOT NULL,
  title TEXT NOT NULL, pairs TEXT NOT NULL      -- JSON [{a,b,avi,bvi}]
);
CREATE INDEX dialog_sid ON dialog(sid, position);

CREATE TABLE grammar_lesson (
  ref INTEGER PRIMARY KEY,         -- 1-based, as used by ?n references everywhere
  title TEXT NOT NULL, chapter INTEGER NOT NULL, drills INTEGER NOT NULL, body TEXT NOT NULL
);

CREATE TABLE exercise_menu (idx INTEGER PRIMARY KEY, name TEXT NOT NULL, start INTEGER NOT NULL, end INTEGER NOT NULL);
CREATE TABLE exercise_title (tt INTEGER NOT NULL, context TEXT NOT NULL, title TEXT NOT NULL, PRIMARY KEY (tt, context));
CREATE TABLE exercise (
  id INTEGER PRIMARY KEY,          -- record index in data.Bt
  menu INTEGER,                    -- 0..8 for the right-column menus, NULL for lesson drills
  lesson_ref INTEGER,              -- first grammar reference (drills), NULL otherwise
  g TEXT NOT NULL, kind TEXT NOT NULL, tt INTEGER NOT NULL DEFAULT 0, text TEXT NOT NULL,
  blanks TEXT, given TEXT, choices TEXT, answer TEXT, vi TEXT, expl TEXT, refs TEXT
);
CREATE INDEX exercise_menu_idx ON exercise(menu, id);
CREATE INDEX exercise_lesson ON exercise(lesson_ref, id);

CREATE TABLE wordform_family (id INTEGER PRIMARY KEY, members TEXT NOT NULL);   -- JSON [{w,pos}]
CREATE TABLE wordform_member (word TEXT NOT NULL, family_id INTEGER NOT NULL REFERENCES wordform_family(id));
CREATE INDEX wordform_member_word ON wordform_member(word);
CREATE TABLE wordform_root (position INTEGER PRIMARY KEY, root TEXT NOT NULL, start INTEGER NOT NULL, count INTEGER NOT NULL, common INTEGER NOT NULL);

CREATE TABLE listening_item (id INTEGER PRIMARY KEY, unit INTEGER NOT NULL, n INTEGER NOT NULL, en TEXT NOT NULL, correct TEXT NOT NULL, options TEXT NOT NULL);
CREATE TABLE analysis_lesson (id INTEGER PRIMARY KEY, words TEXT NOT NULL);
CREATE TABLE picture_topic (id INTEGER PRIMARY KEY, title TEXT NOT NULL, first INTEGER NOT NULL, words TEXT NOT NULL, page TEXT);
CREATE TABLE subtitle_film (id INTEGER PRIMARY KEY, code TEXT NOT NULL, grp TEXT NOT NULL, title TEXT NOT NULL, first_line TEXT, video TEXT NOT NULL, duration REAL NOT NULL, lines INTEGER NOT NULL);
CREATE TABLE subtitle_line (film_id INTEGER NOT NULL REFERENCES subtitle_film(id), idx INTEGER NOT NULL, s REAL NOT NULL, e REAL NOT NULL, en TEXT NOT NULL, vi TEXT, PRIMARY KEY (film_id, idx));
CREATE TABLE help_topic (id INTEGER PRIMARY KEY, title TEXT NOT NULL, text TEXT NOT NULL);
"""


def _j(obj) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(',', ':'))


def _load(path: Path):
    return json.loads(path.read_text(encoding='utf-8'))


# Relative path prefixes of pictures that must travel inside grammar.db.
EMBED_PREFIXES = ('img/pages/',)
MIME = {'.webp': 'image/webp', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png'}


def embed_required_media(cur, dataset: Path) -> tuple[int, int]:
    """Copy the required pictures referenced by the content into the media table."""
    paths = sorted({p for (p,) in cur.execute('SELECT page FROM picture_topic WHERE page IS NOT NULL')
                    if p.startswith(EMBED_PREFIXES)})
    n = size = 0
    for rel in paths:
        f = dataset / rel
        if not f.is_file():
            raise SystemExit(f'required picture missing: {f}')
        data = f.read_bytes()
        cur.execute('INSERT INTO media VALUES (?,?,?)', (rel, MIME.get(f.suffix.lower(), 'application/octet-stream'), data))
        n += 1
        size += len(data)
    return n, size


def pack(dataset: Path, out: Path, content: dict) -> None:
    if out.exists():
        out.unlink()
    out.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(out)
    con.executescript(SCHEMA)
    cur = con.cursor()
    counts: dict[str, int] = {}

    # ---- dictionary
    index = _load(dataset / 'dict' / 'index.json')
    n = 0
    for shard in sorted(index['shards']):
        rows = []
        for e in _load(dataset / 'dict' / f'{shard}.json'):
            rows.append((e['h'], e['k'], e.get('ipa'), _j(e['segs']), _j(e['q']) if 'q' in e else None,
                         e.get('redirect')))
        cur.executemany('INSERT INTO dict_entry(headword,key,ipa,segs,quick,redirect) VALUES (?,?,?,?,?,?)', rows)
        n += len(rows)
    counts['dict_entry'] = n
    for q in _load(dataset / 'dict' / 'quick.json'):
        cur.execute('INSERT OR IGNORE INTO quick_def VALUES (?,?,?,?,?,?)',
                    (search_key(q['w']), q['w'], q.get('ipa'), q.get('rs'), q.get('pos'), q['vi']))
    counts['quick_def'] = cur.execute('SELECT count(*) FROM quick_def').fetchone()[0]

    # ---- readings
    toc = _load(dataset / 'readings' / 'toc.json')
    sections = []

    def walk(node, parent, depth):
        sid = node['sid']
        sections.append((sid, parent, node['title'], depth, len(sections)))
        for c in node.get('children', []):
            walk(c, sid, depth + 1)
        if 'file' in node:
            for pos, r in enumerate(_load(dataset / 'readings' / node['file'])):
                cur.execute('INSERT INTO reading VALUES (?,?,?,?,?,?,?,?,?,?,?)',
                            (r['id'], sid, pos, r['title'], r.get('img'), r.get('audio'),
                             _j(r['times']) if 'times' in r else None, int(r.get('titleAudio', False)),
                             r.get('page'), _j(r['en']), _j(r['vi'])))
                idx = 0
                vi_flat = [s for p in r['vi'] for s in p]
                for p, para in enumerate(r['en']):
                    for s in para:
                        cur.execute('INSERT INTO reading_sentence VALUES (?,?,?,?,?)',
                                    (r['id'], idx, p, s, vi_flat[idx] if idx < len(vi_flat) else None))
                        idx += 1
    walk(toc, None, 0)
    cur.executemany('INSERT INTO reading_section VALUES (?,?,?,?,?)', sections)
    counts['reading'] = cur.execute('SELECT count(*) FROM reading').fetchone()[0]
    counts['reading_sentence'] = cur.execute('SELECT count(*) FROM reading_sentence').fetchone()[0]

    # ---- dialogs
    dtoc = _load(dataset / 'dialogs' / 'toc.json')
    for pos, t in enumerate(dtoc['topics']):
        cur.execute('INSERT INTO dialog_topic VALUES (?,?,?)', (t['sid'], t['title'], pos))
        for p, d in enumerate(_load(dataset / 'dialogs' / t['file'])):
            cur.execute('INSERT INTO dialog VALUES (?,?,?,?,?)', (d['id'], t['sid'], p, d['title'], _j(d['pairs'])))
    cur.execute('INSERT INTO meta VALUES (?,?)', ('dialog_images', _j(dtoc.get('images', []))))
    cur.execute('INSERT INTO meta VALUES (?,?)', ('dialog_page_images', _j(dtoc.get('page_images', []))))
    counts['dialog'] = cur.execute('SELECT count(*) FROM dialog').fetchone()[0]

    # ---- grammar
    # '@.' in datavp marks 131 lessons, but only the lessons that own records in data.Muc
    # (97) have exercises; the app's "Làm Bài Tập" follows the data.
    drill_refs = set(_load(dataset / 'exercises' / 'menus.json').get('drill_lessons', []))
    for l in _load(dataset / 'grammar' / 'lessons.json'):
        cur.execute('INSERT INTO grammar_lesson VALUES (?,?,?,?,?)', (l['ref'], l['title'], int(l['chapter']), int(l['ref'] in drill_refs), l['body']))
    counts['grammar_lesson'] = cur.execute('SELECT count(*) FROM grammar_lesson').fetchone()[0]

    # ---- exercises
    menus = _load(dataset / 'exercises' / 'menus.json')

    titles = _load(dataset / 'exercises' / 'titles.json')
    for ctx in ('menu', 'lesson'):
        cur.executemany('INSERT INTO exercise_title VALUES (?,?,?)', [(int(k), ctx, v) for k, v in titles[ctx].items()])
    cur.execute('INSERT INTO meta VALUES (?,?)', ('exercise_group_size', str(titles['group_size'])))

    def ins_ex(e, menu, lesson_ref):
        cur.execute('INSERT INTO exercise VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
                    (e['id'], menu, lesson_ref, e['g'], e['kind'], e.get('tt', 0), e['text'],
                     _j(e['blanks']) if 'blanks' in e else None, _j(e['given']) if 'given' in e else None,
                     _j(e['choices']) if 'choices' in e else None, e.get('answer'), e.get('vi'),
                     _j(e['expl']) if 'expl' in e else None, _j(e['refs']) if 'refs' in e else None))
    for k, m in enumerate(menus['menus']):
        cur.execute('INSERT INTO exercise_menu VALUES (?,?,?,?)', (k, m['name'], m['start'], m['end']))
        files = [f['file'] for f in m['files']] if 'files' in m else [m['file']]
        for f in files:
            for e in _load(dataset / 'exercises' / f):
                ins_ex(e, k, None)
    drills = _load(dataset / 'exercises' / menus['drills'])
    for ref, items in drills.items():
        for e in items:
            ins_ex(e, None, int(ref) or None)
    counts['exercise'] = cur.execute('SELECT count(*) FROM exercise').fetchone()[0]

    # ---- word forms
    for i, fam in enumerate(_load(dataset / 'wordforms' / 'families.json')):
        cur.execute('INSERT INTO wordform_family VALUES (?,?)', (i, _j(fam)))
        cur.executemany('INSERT INTO wordform_member VALUES (?,?)', [(m['w'].lower(), i) for m in fam])
    common = set(w.lower() for w in _load(dataset / 'wordforms' / 'common.json'))
    for pos, r in enumerate(_load(dataset / 'wordforms' / 'roots.json')):
        cur.execute('INSERT INTO wordform_root VALUES (?,?,?,?,?)', (pos, r['root'], r['start'], r['count'], int(r['root'].lower() in common)))
    counts['wordform_family'] = cur.execute('SELECT count(*) FROM wordform_family').fetchone()[0]

    # ---- listening, analysis, pictures, subtitles, help
    for it in _load(dataset / 'listening' / 'units.json'):
        cur.execute('INSERT INTO listening_item VALUES (?,?,?,?,?,?)', (it['id'], it['unit'], it['n'], it['en'], it['correct'], _j(it['options'])))
    for a in _load(dataset / 'analysis' / 'lessons.json'):
        cur.execute('INSERT INTO analysis_lesson VALUES (?,?)', (a['id'], _j(a['words'])))
    for t in _load(dataset / 'pictures' / 'topics.json'):
        cur.execute('INSERT INTO picture_topic VALUES (?,?,?,?,?)', (t['id'], t['title'], t['first'], _j(t['words']), t.get('page')))
    for f in _load(dataset / 'subtitles' / 'films.json'):
        cur.execute('INSERT INTO subtitle_film VALUES (?,?,?,?,?,?,?,?)',
                    (f['id'], f['code'], f['group'], f['title'], f.get('first_line'), f['video'], f['duration'], f['lines']))
        film = _load(dataset / 'subtitles' / f['file'])
        cur.executemany('INSERT INTO subtitle_line VALUES (?,?,?,?,?,?)',
                        [(f['id'], i, ln['s'], ln['e'], ln['en'], ln['vi']) for i, ln in enumerate(film['lines'])])
    for h in _load(dataset / 'help' / 'topics.json'):
        cur.execute('INSERT INTO help_topic VALUES (?,?,?)', (h['id'], h['title'], h['text']))
    for tbl in ('listening_item', 'analysis_lesson', 'picture_topic', 'subtitle_film', 'subtitle_line', 'help_topic'):
        counts[tbl] = cur.execute(f'SELECT count(*) FROM {tbl}').fetchone()[0]

    n_media, media_bytes = embed_required_media(cur, dataset)
    counts['media'] = n_media

    # ---- full-text indexes and metadata
    cur.execute("INSERT INTO dict_fts(dict_fts) VALUES ('rebuild')")
    cur.execute("INSERT INTO reading_sentence_fts(reading_sentence_fts) VALUES ('rebuild')")
    cur.executemany('INSERT INTO meta VALUES (?,?)', [
        ('format', '1'),
        ('schema_version', str(content['schema'])),
        ('content_version', content['version']),
        ('content_date', content.get('date', '')),
        ('built', time.strftime('%Y-%m-%dT%H:%M:%S')),
        ('counts', _j(counts)),
        ('media_note', 'img/pages/* embedded in table media; other img/ and audio/ paths are files in img/ and audio/ next to this database (repo: content/dataset/)'),
    ])
    con.commit()
    con.execute('VACUUM')
    con.close()
    size = out.stat().st_size / 1e6
    print(f"{out}: content {content['version']} (schema {content['schema']}), {size:.1f} MB")
    print('  ' + ', '.join(f'{k}={v}' for k, v in counts.items()))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--dataset', default=str(CONTENT / 'dataset'))
    ap.add_argument('--out', default=str(CONTENT / 'grammar.db'))
    a = ap.parse_args()
    content = json.loads((CONTENT / 'content.json').read_text(encoding='utf-8'))
    pack(Path(a.dataset), Path(a.out), content)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

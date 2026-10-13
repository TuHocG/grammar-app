"""Validate content/dataset before building or releasing: readable JSON in the diff-friendly layout
of tool/content/jsonfmt.py, no duplicate ids, stable ids.

    python3 tool/content/check.py            # compare with content/ids.json, exit 1 on a breaking change
    python3 tool/content/check.py --update   # after ADDING content: record the new ids in content/ids.json

Why: the app's user.db stores the learner's state by content id — saved dialog sentences (dialog
id + pair index), picked picture hotspots (topic id + word index), Word Forms marks (root
position), last reading / lesson / topic opened, exercise progress (menu index). An edit may add
ids; it must never remove an id, renumber, or put a different item behind an existing id. An item
that really has to go is listed in content/retired.json: its id is then allowed to disappear and is
never reused.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

CONTENT = Path(__file__).resolve().parents[2] / 'content'
DS = CONTENT / 'dataset'
SNAPSHOT = CONTENT / 'ids.json'
# Ids deliberately retired (never reused): {"readings": [...], "reading_sections": [...], ...}
RETIRED = CONTENT / 'retired.json'


def _j(p: Path):
    return json.loads(p.read_text(encoding='utf-8'))


def collect() -> tuple[dict, list[str]]:
    errs: list[str] = []
    ids: dict = {}

    sections: list[int] = []
    readings: list[int] = []

    def walk(node):
        if node.get('sid', -1) >= 0:
            sections.append(node['sid'])
        if 'file' in node:
            readings.extend(r['id'] for r in _j(DS / 'readings' / node['file']))
        for c in node.get('children', []):
            walk(c)
    walk(_j(DS / 'readings' / 'toc.json'))
    ids['reading_sections'] = sections
    ids['readings'] = readings

    dtoc = _j(DS / 'dialogs' / 'toc.json')
    ids['dialog_topics'] = [t['sid'] for t in dtoc['topics']]
    dialogs: dict[str, int] = {}
    for t in dtoc['topics']:
        for d in _j(DS / 'dialogs' / t['file']):
            if str(d['id']) in dialogs:
                errs.append(f"dialog id {d['id']} appears twice")
            dialogs[str(d['id'])] = len(d['pairs'])
    ids['dialogs'] = dialogs

    ids['grammar_lessons'] = [l['ref'] for l in _j(DS / 'grammar' / 'lessons.json')]
    ids['pictures'] = {str(t['id']): [w['en'] for w in t['words']] for t in _j(DS / 'pictures' / 'topics.json')}
    ids['wordform_roots'] = [r['root'] for r in _j(DS / 'wordforms' / 'roots.json')]
    ids['listening_units'] = sorted({it['unit'] for it in _j(DS / 'listening' / 'units.json')})
    ids['films'] = {str(f['id']): f['code'] for f in _j(DS / 'subtitles' / 'films.json')}
    ids['analysis'] = [a['id'] for a in _j(DS / 'analysis' / 'lessons.json')]
    ids['exercise_menus'] = [m['name'] for m in _j(DS / 'exercises' / 'menus.json')['menus']]

    for key in ('reading_sections', 'readings', 'dialog_topics', 'grammar_lessons', 'analysis'):
        seen: set = set()
        for v in ids[key]:
            if v in seen:
                errs.append(f'{key}: id {v} appears twice')
            seen.add(v)
    return ids, errs


def compare(old: dict, new: dict, retired: dict | None = None) -> tuple[list[str], list[str]]:
    bad: list[str] = []
    warn: list[str] = []
    retired = retired or {}
    for key in ('reading_sections', 'readings', 'dialog_topics', 'grammar_lessons', 'listening_units', 'analysis'):
        gone = sorted(set(old.get(key, [])) - set(new[key]) - set(retired.get(key, [])))
        reused = sorted(set(retired.get(key, [])) & set(new[key]))
        if reused:
            bad.append(f'{key}: retired ids reused {reused[:20]}')
        if gone:
            bad.append(f'{key}: removed ids {gone[:20]}{" …" if len(gone) > 20 else ""}')
    for did, n in old.get('dialogs', {}).items():
        if did not in new['dialogs']:
            bad.append(f'dialogs: removed id {did}')
        elif new['dialogs'][did] < n:
            bad.append(f'dialogs: id {did} lost pairs ({n} -> {new["dialogs"][did]}); picked sentences are pair indexes')
    for tid, words in old.get('pictures', {}).items():
        cur = new['pictures'].get(tid)
        if cur is None:
            bad.append(f'pictures: removed topic {tid}')
            continue
        if len(cur) < len(words):
            bad.append(f'pictures: topic {tid} lost words ({len(words)} -> {len(cur)}); picks are word indexes')
        for i, (a, b) in enumerate(zip(words, cur)):
            if a != b:
                warn.append(f'pictures: topic {tid} word {i} "{a}" -> "{b}" (ok for a spelling fix, not for a different word)')
    old_roots = old.get('wordform_roots', [])
    for i, root in enumerate(old_roots):
        if i >= len(new['wordform_roots']):
            bad.append(f'wordform_roots: shortened ({len(old_roots)} -> {len(new["wordform_roots"])}); marks are positions')
            break
        if new['wordform_roots'][i] != root:
            bad.append(f'wordform_roots: position {i} was "{root}", now "{new["wordform_roots"][i]}"; add new roots at the end')
            break
    for fid, code in old.get('films', {}).items():
        if new['films'].get(fid) != code:
            bad.append(f'films: id {fid} was {code}, now {new["films"].get(fid)}')
    om, nm = old.get('exercise_menus', []), new['exercise_menus']
    if nm[:len(om)] != om:
        bad.append(f'exercise_menus: order/names changed {om} -> {nm}; progress is stored per menu index')
    return bad, warn


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--update', action='store_true', help='write the current ids to content/ids.json')
    a = ap.parse_args()
    version = _j(CONTENT / 'content.json')['version']
    try:
        new, errs = collect()
    except (OSError, ValueError, KeyError) as e:
        print(f'ERROR reading content/dataset: {e}')
        return 1
    retired = _j(RETIRED) if RETIRED.exists() else {}
    bad, warn = compare(_j(SNAPSHOT), new, retired) if SNAPSHOT.exists() else ([], [])
    for w in warn:
        print('warning:', w)
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from jsonfmt import off_layout
    off = off_layout()
    errs += [f'{p.relative_to(CONTENT)} is not in the dataset layout: run python3 tool/content/jsonfmt.py' for p in off[:10]]
    if len(off) > 10:
        errs.append(f'... and {len(off) - 10} more files not in the layout')
    for e in errs + bad:
        print('ERROR:', e)
    if errs or bad:
        print(f'{len(errs) + len(bad)} breaking problem(s) in content {version}.')
        return 1
    if a.update or not SNAPSHOT.exists():
        SNAPSHOT.write_text(json.dumps(new, ensure_ascii=False, indent=1) + '\n', encoding='utf-8', newline='\n')
        print(f'content/ids.json updated ({version})')
    print(f'ok: content {version}')
    return 0


if __name__ == '__main__':
    sys.exit(main())

"""Canonical, diff-friendly layout of the content JSON (content/dataset/**/*.json).

    python3 tool/content/jsonfmt.py            # rewrite every dataset file that is not in the layout
    python3 tool/content/jsonfmt.py --check    # list files not in the layout, exit 1 if any

Layout: two-space indent; an array or object that fits in WIDTH characters on its line stays on
one line, a longer one gets one element per line. So every sentence of a reading, every dialog
pair and every dictionary sense is its own line, and a one-word fix shows as a one-line diff.
Scripts that write dataset files (here and in grammar-legacy) call dumps() so the layout stays.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

DS = Path(__file__).resolve().parents[2] / 'content' / 'dataset'
WIDTH = 100


def _compact(o) -> str:
    return json.dumps(o, ensure_ascii=False, separators=(', ', ': '))


def _fmt(o, indent: int, lead: int = 0) -> str:
    """o laid out at nesting `indent`; `lead` = characters already on its first line (a key)."""
    one = _compact(o)
    if not isinstance(o, (list, dict)) or not o or indent + lead + len(one) <= WIDTH:
        return one
    pad = ' ' * (indent + 2)
    if isinstance(o, list):
        body = (pad + _fmt(x, indent + 2) for x in o)
        return '[\n' + ',\n'.join(body) + '\n' + ' ' * indent + ']'
    body = []
    for k, v in o.items():
        key = json.dumps(k, ensure_ascii=False) + ': '
        body.append(pad + key + _fmt(v, indent + 2, len(key)))
    return '{\n' + ',\n'.join(body) + '\n' + ' ' * indent + '}'


def dumps(o) -> str:
    """The file text for o, ending with a newline."""
    return _fmt(o, 0) + '\n'


def write(path: Path, o) -> None:
    Path(path).write_text(dumps(o), encoding='utf-8', newline='\n')


def off_layout(fix: bool = False) -> list[Path]:
    """Dataset files whose text is not dumps() of their data; rewritten when fix."""
    off = []
    for p in sorted(DS.rglob('*.json')):
        raw = p.read_text(encoding='utf-8')
        text = dumps(json.loads(raw))
        if raw.replace('\r\n', '\n') != text:   # a Windows checkout may turn LF into CRLF
            off.append(p)
            if fix:
                p.write_text(text, encoding='utf-8', newline='\n')
    return off


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    a = ap.parse_args()
    off = off_layout(fix=not a.check)
    rel = [str(p.relative_to(DS.parent)) for p in off]
    if a.check:
        for r in rel[:20]:
            print('not in layout:', r)
        if off:
            print(f'{len(off)} files not in layout: run python3 tool/content/jsonfmt.py', file=sys.stderr)
        return 1 if off else 0
    print(f'{len(off)} files rewritten')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

"""Serve the web app with its data for a local try-out (docs/07 §12).

    python3 tool/web/build_web.py
    python3 tool/content/bundle.py --host          # build/host: the data (once per content change)
    python3 tool/web/serve.py                      # http://localhost:8080 from build/web + build/host

Looks each path up in build/web first, then build/host, so the app and its data share one origin
as on the real host; `_headers` of Cloudflare Pages are not applied (only the wasm content type).
While developing, run the app with hot restart from another port and point it at this server for
the data: `flutter run -d chrome --dart-define=GRAMMAR_HOST_URL=http://localhost:8080/`.
Standalone, stdlib only.
"""
from __future__ import annotations

import argparse
import mimetypes
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class Handler(SimpleHTTPRequestHandler):
    roots: list[Path] = []

    def translate_path(self, path: str) -> str:
        rel = Path(super().translate_path(path)).relative_to(self.directory)
        for root in self.roots:
            if (root / rel).exists():
                return str(root / rel)
        return str(self.roots[0] / rel)

    def end_headers(self) -> None:
        self.send_header('Cache-Control', 'no-store')
        # `flutter run -d chrome` serves the app from another port and fetches the data from here.
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

    def log_message(self, format: str, *args) -> None:  # noqa: A002 (stdlib signature)
        if '404' in (args[1] if len(args) > 1 else ''):
            super().log_message(format, *args)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--port', type=int, default=8080)
    ap.add_argument('--roots', nargs='*', type=Path, default=[ROOT / 'build' / 'web', ROOT / 'build' / 'host'])
    a = ap.parse_args()
    mimetypes.add_type('application/wasm', '.wasm')
    Handler.roots = [r.resolve() for r in a.roots]
    for r in Handler.roots:
        if not r.is_dir():
            raise SystemExit(f'{r} is missing (see the module docstring)')
    print(f'http://localhost:{a.port}/  ({" + ".join(str(r.relative_to(ROOT)) for r in Handler.roots)})')
    ThreadingHTTPServer(('127.0.0.1', a.port), partial(Handler, directory=str(ROOT))).serve_forever()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

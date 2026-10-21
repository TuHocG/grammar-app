"""Serve the web app with its data for a local try-out (docs/07 §12).

    python3 tool/web/build_web.py
    python3 tool/content/bundle.py --host          # build/host: the data (once per content change)
    python3 tool/web/serve.py                      # http://localhost:8080 from build/web + build/host

Looks each path up in build/web first, then build/host, so the app and its data share one origin
as on the real host; `_headers` of Cloudflare Pages are not applied (only the wasm content type).
While developing, run the app with hot restart from another port and point it at this server for
the data: `flutter run -d chrome --dart-define=GRAMMAR_HOST_URL=http://localhost:8080/`.

--audio DIR also serves the real-voice recordings of DIR (1.mp3 …) under /audio/, like the audio
host: `/audio/<n>` (what the web app asks for) and `/audio/<n>.mp3`, with Range requests so the
player can seek. Build or run the app with `--dart-define=GRAMMAR_AUDIO_URL=http://localhost:8080/audio/`.
Standalone, stdlib only.
"""
from __future__ import annotations

import argparse
import mimetypes
import re
import shutil
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class Handler(SimpleHTTPRequestHandler):
    roots: list[Path] = []
    audio: Path | None = None

    def do_GET(self) -> None:
        m = re.fullmatch(r'/audio/(\d+)(?:\.mp3)?', self.path.split('?')[0])
        if m and self.audio is not None:
            self._send_audio(self.audio / f'{m.group(1)}.mp3')
        else:
            super().do_GET()

    def _send_audio(self, f: Path) -> None:
        """The recording, whole or the byte range asked for (`bytes=a-` or `bytes=a-b`)."""
        if not f.is_file():
            self.send_error(404)
            return
        size = f.stat().st_size
        start, end = 0, size - 1
        r = re.fullmatch(r'bytes=(\d+)-(\d*)', self.headers.get('Range', ''))
        if r:
            start = int(r.group(1))
            end = min(int(r.group(2)), size - 1) if r.group(2) else size - 1
            if start >= size:
                self.send_response(416)
                self.send_header('Content-Range', f'bytes */{size}')
                self.end_headers()
                return
        self.send_response(206 if r else 200)
        self.send_header('Content-Type', 'audio/mpeg')
        self.send_header('Accept-Ranges', 'bytes')
        self.send_header('Content-Length', str(end - start + 1))
        if r:
            self.send_header('Content-Range', f'bytes {start}-{end}/{size}')
        self.send_header('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Accept-Ranges')
        self.end_headers()
        with f.open('rb') as src:
            src.seek(start)
            try:
                shutil.copyfileobj(_Limited(src, end - start + 1), self.wfile)
            except (BrokenPipeError, ConnectionResetError):
                pass  # the player moved on (seek, next reading)

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


class _Limited:
    """The next [n] bytes of a file, for copyfileobj."""

    def __init__(self, f, n: int) -> None:
        self.f, self.left = f, n

    def read(self, size: int = -1) -> bytes:
        if self.left <= 0:
            return b''
        b = self.f.read(self.left if size < 0 else min(size, self.left))
        self.left -= len(b)
        return b


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--port', type=int, default=8080)
    ap.add_argument('--roots', nargs='*', type=Path, default=[ROOT / 'build' / 'web', ROOT / 'build' / 'host'])
    ap.add_argument('--audio', type=Path, metavar='DIR', help='serve the recordings of DIR (1.mp3 …) under /audio/')
    a = ap.parse_args()
    mimetypes.add_type('application/wasm', '.wasm')
    Handler.roots = [r.resolve() for r in a.roots]
    if a.audio is not None:
        if not a.audio.is_dir():
            raise SystemExit(f'{a.audio} is not a folder')
        Handler.audio = a.audio.resolve()
        print(f'recordings of {Handler.audio} under /audio/')
    for r in Handler.roots:
        if not r.is_dir():
            raise SystemExit(f'{r} is missing (see the module docstring)')
    print(f'http://localhost:{a.port}/  ({" + ".join(str(r.relative_to(ROOT)) for r in Handler.roots)})')
    ThreadingHTTPServer(('127.0.0.1', a.port), partial(Handler, directory=str(ROOT))).serve_forever()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

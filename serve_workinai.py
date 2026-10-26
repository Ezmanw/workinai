#!/usr/bin/env python3
"""Serve the built WorkinAI web app on a free loopback port and open a browser."""

from __future__ import annotations

import http.server
import os
import sys
import threading
import webbrowser

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")
INDEX = os.path.join(ROOT, "index.html")


class Handler(http.server.SimpleHTTPRequestHandler):
    """Static file handler with simple no-store headers for local development."""

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()

    def log_message(self, fmt: str, *args: object) -> None:  # quieter console
        pass


def main() -> int:
    if not os.path.isfile(INDEX):
        print("No web build found.")
        print("Run: flutter build web --release --no-web-resources-cdn")
        return 1

    os.chdir(ROOT)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    port = server.server_address[1]
    url = f"http://127.0.0.1:{port}/"
    print(f"WorkinAI is running at {url}")
    print("Press Ctrl+C (or close this window) to stop.")

    threading.Timer(0.8, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())

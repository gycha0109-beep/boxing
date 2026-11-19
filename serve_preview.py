from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "build" / "web"

class PreviewHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", 8765), partial(PreviewHandler, directory=str(ROOT)))
    print("Twelve Count local web preview: http://127.0.0.1:8765/index.html", flush=True)
    server.serve_forever()

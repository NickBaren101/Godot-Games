"""Local preview server for the web build.

The Web preset has thread_support on, so the page needs cross-origin isolation
(SharedArrayBuffer). Plain file:// or a bare static server fails with
"Cross-Origin Isolation missing". Run this from build/web:

    python serve.py        # then open http://localhost:8000/index.html
"""

import http.server
import socketserver

PORT = 8000


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"Serving on http://localhost:{PORT}/index.html (Ctrl+C to stop)")
    httpd.serve_forever()

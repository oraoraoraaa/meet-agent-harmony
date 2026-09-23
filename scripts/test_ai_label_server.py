#!/usr/bin/env python3
"""Loopback-only UI test fixture. Never use its screenshots as live model evidence.

Run alongside Native map smoke's AI disclosure test:
  hdc rport tcp:18766 tcp:18766
  python3 scripts/test_ai_label_server.py
Restore settings is handled by the native test's finally block.
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers.get('Content-Length', '0')))
        body = json.dumps({'choices': [{'message': {'role': 'assistant', 'content':
            '标识验证测试回复：请查看路线卡片，并在出发前核实实际道路通行情况。'},
            'finish_reason': 'stop'}]}, ensure_ascii=False).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass

HTTPServer(('127.0.0.1', 18766), Handler).serve_forever()

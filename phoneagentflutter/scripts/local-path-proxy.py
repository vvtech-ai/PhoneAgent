#!/usr/bin/env python3
import http.client
import select
import socket
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LISTEN, TARGET, PREFIX = int(sys.argv[1]), sys.argv[2], sys.argv[3].rstrip('/')
HOST, PORT = TARGET.split(':')
PORT = int(PORT)

class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def do_GET(self): self.forward()
    def do_POST(self): self.forward()
    def do_PUT(self): self.forward()
    def do_DELETE(self): self.forward()
    def forward(self):
        path = self.path
        if not path.startswith(PREFIX + '/') and path != PREFIX:
            self.send_error(404)
            return
        rewritten = path[len(PREFIX):] or '/'
        length = int(self.headers.get('Content-Length', '0'))
        body = self.rfile.read(length) if length else None
        headers = {k: v for k, v in self.headers.items() if k.lower() != 'host'}
        if self.headers.get('Upgrade', '').lower() == 'websocket':
            self.forward_websocket(rewritten, headers)
            return
        conn = http.client.HTTPConnection(HOST, PORT, timeout=120)
        try:
            conn.request(self.command, rewritten, body=body, headers=headers)
            response = conn.getresponse()
            self.send_response(response.status, response.reason)
            for key, value in response.getheaders():
                if key.lower() not in {'connection', 'transfer-encoding', 'keep-alive'}:
                    self.send_header(key, value)
            self.send_header('Connection', 'close')
            self.end_headers()
            while True:
                chunk = response.read(64 * 1024)
                if not chunk:
                    break
                self.wfile.write(chunk)
                self.wfile.flush()
        except Exception as exc:
            if not self.wfile.closed:
                self.send_error(502, str(exc))
        finally:
            conn.close()

    def forward_websocket(self, path, headers):
        upstream = socket.create_connection((HOST, PORT), timeout=10)
        try:
            lines = [f'{self.command} {path} HTTP/1.1']
            lines.extend(f'{key}: {value}' for key, value in headers.items())
            lines.append(f'Host: {HOST}:{PORT}')
            upstream.sendall(('\r\n'.join(lines) + '\r\n\r\n').encode())
            self.connection.setblocking(False)
            upstream.setblocking(False)
            sockets = [self.connection, upstream]
            while True:
                readable, _, exceptional = select.select(sockets, [], sockets, 120)
                if exceptional or not readable:
                    break
                for source in readable:
                    data = source.recv(64 * 1024)
                    if not data:
                        return
                    destination = upstream if source is self.connection else self.connection
                    destination.sendall(data)
        finally:
            upstream.close()
    def log_message(self, *_): pass

ThreadingHTTPServer(('127.0.0.1', LISTEN), Handler).serve_forever()

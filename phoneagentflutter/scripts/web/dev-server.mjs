import http from 'node:http';
import https from 'node:https';
import { pathToFileURL } from 'node:url';

// Local-only, fixed upstream. No URL parameter or public proxy mode.
export function createDevServer({
  api = new URL('https://agent.vvtech.tech'),
  app = new URL('http://127.0.0.1:8090'),
  translationCatalog = {
    DEFAULT: new URL('https://translate-us-webrtc.vvtech.tech'),
    US: new URL('https://translate-test-us-webrtc.vvtech.tech'),
    JP: new URL('https://translate-test-jp-webrtc.vvtech.tech'),
  },
} = {}) {
  return http.createServer((req, res) => {
    const port = res.socket.localPort;
    const hosts = new Set([`localhost:${port}`, `127.0.0.1:${port}`]);
    if (!hosts.has(req.headers.host) ||
        (req.headers.origin &&
          ![...hosts].some(host => req.headers.origin === `http://${host}`))) {
      res.writeHead(403).end('Local development access only');
      return;
    }
    const path = req.url ?? '/';
    if (!path.startsWith('/') || path.startsWith('//') ||
        /\\|%2f|%5c|(?:^|\/)\.\.(?:\/|$)/i.test(path)) {
      res.writeHead(400).end('Invalid path');
      return;
    }
    const isApi = path.startsWith('/aiassistant-api/');
    const isCatalog = path.startsWith('/translation-catalog/');
    const catalogMatch = /^\/translation-catalog\/(DEFAULT|US|JP)\/api\/app-translation-calls\/languages$/.exec(path);
    if (isCatalog && (!catalogMatch || req.method !== 'GET')) {
      res.writeHead(405).end('Read-only translation catalog');
      return;
    }
    const target = isCatalog
      ? new URL('/api/app-translation-calls/languages', translationCatalog[catalogMatch[1]])
      : new URL(path, isApi ? api : app);
    if (isApi && !target.pathname.startsWith('/aiassistant-api/')) {
      res.writeHead(400).end('Invalid API path');
      return;
    }
    if (!['GET', 'HEAD'].includes(req.method) && !isApi) {
      res.writeHead(405).end();
      return;
    }
    const headers = { ...req.headers, host: target.host };
    // Browser policy applies at this same-origin boundary; never forward cookies.
    for (const name of ['origin', 'referer', 'cookie', 'connection']) delete headers[name];
    if (isCatalog) {
      // Public endpoint: do not forward any caller-supplied credentials.
      for (const name of Object.keys(headers)) {
        if (!['host', 'accept', 'user-agent'].includes(name)) delete headers[name];
      }
    }
    headers['accept-encoding'] = 'identity';
    const upstream = (target.protocol === 'https:' ? https : http).request(
      target, { method: req.method, headers }, response => {
        const safeHeaders = { ...response.headers, 'cache-control': 'no-store' };
        delete safeHeaders['set-cookie'];
        delete safeHeaders['access-control-allow-origin'];
        delete safeHeaders['connection'];
        res.writeHead(response.statusCode ?? 502, safeHeaders);
        res.flushHeaders();
        response.pipe(res);
        response.on('error', () => res.destroy());
      },
    );
    upstream.setTimeout(120_000, () => upstream.destroy());
    upstream.on('error', () => {
      if (!res.headersSent) res.writeHead(502).end('Development upstream unavailable');
      else res.destroy();
    });
    req.on('aborted', () => upstream.destroy());
    res.on('close', () => upstream.destroy());
    req.pipe(upstream);
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  createDevServer().listen(8080, '127.0.0.1', () => {
    console.log('PhoneAgent Web: http://localhost:8080 (test API; loopback only)');
  });
}

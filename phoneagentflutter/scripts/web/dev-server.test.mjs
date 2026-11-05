import assert from 'node:assert/strict';
import http from 'node:http';
import { test } from 'node:test';
import { once } from 'node:events';
import { createDevServer } from './dev-server.mjs';

test('translation proxy only permits fixed catalog GET and strips credentials', async () => {
  let queries = 0;
  const upstream = http.createServer((req, res) => {
    queries++;
    assert.equal(req.method, 'GET');
    assert.equal(req.url, '/api/app-translation-calls/languages');
    for (const header of ['authorization', 'cookie', 'x-account-id', 'x-user-id', 'x-api-key']) {
      assert.equal(req.headers[header], undefined);
    }
    res.setHeader('content-type', 'application/json');
    res.end(JSON.stringify({ languages: [{ code: 'en-US', label: 'English' }] }));
  }).listen(0, '127.0.0.1');
  await once(upstream, 'listening');
  const endpoint = new URL(`http://127.0.0.1:${upstream.address().port}`);
  const proxy = createDevServer({ translationCatalog: { DEFAULT: endpoint, US: endpoint, JP: endpoint } });
  proxy.listen(0, '127.0.0.1');
  await once(proxy, 'listening');
  const base = `http://127.0.0.1:${proxy.address().port}/translation-catalog`;
  try {
    for (const region of ['DEFAULT', 'US', 'JP']) {
      const result = await fetch(`${base}/${region}/api/app-translation-calls/languages`, {
        headers: { Authorization: 'synthetic', Cookie: 'synthetic=1',
          'x-account-id': 'synthetic', 'x-user-id': 'synthetic', 'x-api-key': 'synthetic' },
      });
      assert.equal(result.status, 200);
      assert.equal((await result.json()).languages[0].code, 'en-US');
    }
    for (const path of ['/CN/api/app-translation-calls/languages', '/US/api/app-translation-calls',
      '/US/api/app-translation-calls/languages?url=https://foreign.invalid']) {
      assert.equal((await fetch(base + path)).status, 405);
    }
    assert.equal((await fetch(`${base}/US/api/app-translation-calls/languages`, { method: 'POST' })).status, 405);
    assert.equal(queries, 3);
  } finally {
    proxy.closeAllConnections(); proxy.close();
    upstream.closeAllConnections(); upstream.close();
  }
});

test('proxy rejects foreign origin/host, streams before EOF and cancels upstream', async () => {
  let closed;
  const upstreamClosed = new Promise(resolve => { closed = resolve; });
  const upstream = http.createServer((req, res) => {
    assert.equal(req.url, '/aiassistant-api/stream');
    assert.equal(req.headers.cookie, undefined);
    assert.equal(req.headers['x-account-id'], 'synthetic');
    res.writeHead(200, { 'content-type': 'text/event-stream' });
    res.write('data: first\n\n');
    res.on('close', closed);
    // Deliberately never finish: receiving first bytes proves no buffering.
  }).listen(0, '127.0.0.1');
  await once(upstream, 'listening');
  const proxy = createDevServer({ api: new URL(`http://127.0.0.1:${upstream.address().port}`) });
  proxy.listen(0, '127.0.0.1');
  await once(proxy, 'listening');
  const base = `http://127.0.0.1:${proxy.address().port}`;
  try {
    assert.equal((await fetch(base, { headers: { Origin: 'https://foreign.invalid' } })).status, 403);
    const hostStatus = await new Promise(resolve => {
      http.get(base, { headers: { Host: 'foreign.invalid' } }, res => {
        res.resume(); resolve(res.statusCode);
      });
    });
    assert.equal(hostStatus, 403);
    assert.equal((await fetch(`${base}/%2fprivate`)).status, 400);
    assert.equal((await fetch(base, { method: 'POST' })).status, 405);
    const abort = new AbortController();
    const response = await fetch(`${base}/aiassistant-api/stream`, {
      method: 'POST', body: '{}', signal: abort.signal,
      headers: { 'x-account-id': 'synthetic', Cookie: 'must-not-forward=true' },
    });
    const first = await response.body.getReader().read();
    assert.equal(new TextDecoder().decode(first.value), 'data: first\n\n');
    assert.equal(response.headers.get('cache-control'), 'no-store');
    abort.abort();
    await Promise.race([
      upstreamClosed,
      new Promise((_, reject) => setTimeout(() => reject(Error('upstream not cancelled')), 1500).unref()),
    ]);
  } finally {
    proxy.closeAllConnections(); proxy.close();
    upstream.closeAllConnections(); upstream.close();
  }
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { auditReleasePreviews, requiredMarkers, forbiddenMarkers } from './audit-release-previews.mjs';

const real = requiredMarkers.join('|');
test('known real entry positive controls are mandatory', () => {
  assert.equal(auditReleasePreviews('').passed, false);
  assert.equal(auditReleasePreviews('unrelated compiled code').passed, false);
  assert.equal(auditReleasePreviews(real).passed, true);
});
test('every known preview rejects literal and escaped output', () => {
  for (const marker of forbiddenMarkers) {
    const escaped = [...marker].map(char =>
      `\\u${char.charCodeAt(0).toString(16).padStart(4, '0')}`).join('');
    assert.deepEqual(auditReleasePreviews(`${real}|${marker}`).retainedPreviews, [marker]);
    assert.deepEqual(auditReleasePreviews(`${real}|${escaped}`).retainedPreviews, [marker]);
  }
});
test('dart2js latin byte escapes are decoded without evaluating source', () => {
  const escaped = 'MOCK \\xb7 \\u9009\\u62e9\\u6587\\u6863\\u573a\\u666f';
  assert.equal(auditReleasePreviews(`${real}|${escaped}`).passed, false);
  assert.equal(auditReleasePreviews(`${real}|MOCK shared optional label`).passed, true);
});

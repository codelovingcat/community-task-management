import test from 'node:test';
import assert from 'node:assert/strict';
import { memberPortalUrl } from '../src/lib/memberPortalUrl';
test('portal navigation accepts only a configured safe standalone origin', () => {
  assert.equal(memberPortalUrl('https://portal.example.com'), 'https://portal.example.com/');
  for (const value of ['', null, '//evil.test', 'javascript:alert(1)', 'http://example.com', 'https://user:pass@example.com', 'https://example.com/?access_token=abc', 'https://example.com/#token', 'https://example.com/profile']) {
    assert.equal(memberPortalUrl(value), null);
  }
  assert.equal(memberPortalUrl('http://localhost:5174'), null);
  assert.equal(memberPortalUrl('http://localhost:5174', true), 'http://localhost:5174/');
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { runInNewContext } from 'node:vm';
import React from 'react';
import { act, create } from 'react-test-renderer';
import ts from 'typescript';
const require = createRequire(import.meta.url);
function load(file, deps) {
  const exports = {};
  const source = readFileSync(new URL(`../apps/member-portal/src/${file}`, import.meta.url), 'utf8');
  const code = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX } }).outputText;
  runInNewContext(code, { exports, console, setTimeout, clearTimeout, require: name => {
    if (name === 'react') return React;
    if (name === 'react/jsx-runtime') return require(name);
    if (name in deps) return deps[name];
    throw new Error(`Unexpected import ${name}`);
  }});
  return exports;
}
test('late initial session cannot undo sign-out or an account switch', async () => {
  let callback, initial;
  let unsubscribed = false;
  const client = { auth: {
    onAuthStateChange(fn) { callback = fn; return { data: { subscription: { unsubscribe() { unsubscribed = true; } } } }; },
    getSession: () => new Promise(resolve => { initial = resolve; }),
  }};
  const { usePortalSession } = load('usePortalSession.ts', { './client': { client } });
  function Probe() { return React.createElement('pre', {}, JSON.stringify(usePortalSession())); }
  let view;
  await act(async () => { view = create(React.createElement(Probe)); });
  await act(async () => { callback('SIGNED_IN', { user: { id: 'B' } }); });
  await act(async () => { initial({ data: { session: { user: { id: 'A' } } }, error: null }); });
  assert.match(JSON.stringify(view.toJSON()), /B/);
  assert.doesNotMatch(JSON.stringify(view.toJSON()), /"A"/);
  await act(async () => { callback('SIGNED_OUT', null); });
  assert.match(view.root.findByType('pre').children[0], /"user":null/);
  await act(async () => { view.unmount(); });
  assert.equal(unsubscribed, true);
});
test('profile retries RPC failures and distinguishes an unregistered account', async () => {
  let calls = 0;
  const client = { rpc: async (...args) => {
    assert.deepEqual(args, ['get_my_profile']);
    calls++;
    return calls === 1 ? { data: null, error: { code: 'PGRST202' } } : { data: null, error: null };
  }};
  const { Profile } = load('Profile.tsx', { './client': { client }, './Dashboard': { Dashboard: () => null } });
  let view;
  await act(async () => { view = create(React.createElement(Profile)); });
  assert.match(JSON.stringify(view.toJSON()), /Bilgileriniz yüklenemedi/);
  await act(async () => { view.root.findByType('button').props.onClick(); });
  assert.match(JSON.stringify(view.toJSON()), /Üyeliğiniz henüz eşleştirilmemiş/);
  await act(async () => view.unmount());
});
test('a synchronous auth event takes precedence over initial session lookup', async () => {
  const client = { auth: {
    onAuthStateChange(fn) { fn('SIGNED_IN', { user: { id: 'new-user' } }); return { data: { subscription: { unsubscribe() {} } } }; },
    getSession: async () => ({ data: { session: { user: { id: 'old-user' } } }, error: null }),
  }};
  const { usePortalSession } = load('usePortalSession.ts', { './client': { client } });
  function Probe() { return React.createElement('pre', {}, JSON.stringify(usePortalSession())); }
  let view;
  await act(async () => { view = create(React.createElement(Probe)); });
  assert.match(view.root.findByType('pre').children[0], /new-user/);
  assert.doesNotMatch(view.root.findByType('pre').children[0], /old-user/);
  await act(async () => view.unmount());
});

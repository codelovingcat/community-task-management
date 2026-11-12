import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { runInNewContext } from 'node:vm';
import React from 'react';
import { act, create } from 'react-test-renderer';
import ts from 'typescript';

const require = createRequire(import.meta.url);
const wait = () => new Promise((resolve) => setTimeout(resolve, 5));
function deferred() { let resolve; const promise = new Promise((r) => { resolve = r; }); return { promise, resolve }; }

function fixture() {
  let listener; let latest; const requests = [];
  const pendingSession = deferred();
  const auth = {
    getSession: () => pendingSession.promise,
    onAuthStateChange: (callback) => { listener = callback; return { data: { subscription: { unsubscribe() {} } } }; },
    signOut: async () => ({ error: null }),
  };
  const exports = {};
  const code = ts.transpileModule(readFileSync(new URL('../src/context/UserProfileContext.tsx', import.meta.url), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, esModuleInterop: true },
  }).outputText;
  const dependencies = { react: React, 'react/jsx-runtime': require('react/jsx-runtime'),
    '../lib/supabase': { supabase: { auth } },
    '../lib/supabaseMembers': { getMemberByEmail: (email) => { const result = deferred(); requests.push({ email, ...result }); return result.promise; } } };
  runInNewContext(code, { exports, setTimeout, console, require: (name) => {
    if (name in dependencies) return dependencies[name]; throw new Error(`Unexpected import: ${name}`);
  } });
  function Capture() { latest = exports.useUserProfile(); return null; }
  return { exports, Capture, requests, pendingSession, emit: (event, session) => listener(event, session), value: () => latest };
}
const session = (id) => ({ user: { id, email: `${id}@example.invalid` } });

test('account switches discard delayed profiles and defer data calls until after auth callbacks', async () => {
  const f = fixture(); let view;
  await act(async () => { view = create(React.createElement(f.exports.UserProfileProvider, null, React.createElement(f.Capture))); });
  await act(async () => { assert.equal(f.emit('SIGNED_IN', session('a')), undefined); assert.equal(f.requests.length, 0); await wait(); });
  assert.equal(f.requests[0].email, 'a@example.invalid');
  await act(async () => { f.emit('SIGNED_IN', session('b')); await wait(); });
  assert.equal(f.value().profile, null);
  await act(async () => { f.requests[1].resolve({ id: 'member-b' }); await f.requests[1].promise; });
  assert.equal(f.value().user.id, 'b'); assert.equal(f.value().profile.id, 'member-b');
  await act(async () => { f.requests[0].resolve({ id: 'member-a' }); await f.requests[0].promise; });
  assert.equal(f.value().profile.id, 'member-b');
  // An older initial-session response must not undo a newer auth event.
  await act(async () => { f.pendingSession.resolve({ data: { session: session('a') } }); await f.pendingSession.promise; });
  assert.equal(f.value().user.id, 'b');
  await act(async () => { view.unmount(); });
});

test('a signed-out session cannot be repopulated by an older profile lookup', async () => {
  const f = fixture(); let view;
  await act(async () => { view = create(React.createElement(f.exports.UserProfileProvider, null, React.createElement(f.Capture))); });
  await act(async () => { f.emit('SIGNED_IN', session('a')); await wait(); });
  await act(async () => { f.emit('SIGNED_OUT', null); });
  await act(async () => { f.requests[0].resolve({ id: 'member-a' }); await f.requests[0].promise; });
  assert.equal(f.value().user, null); assert.equal(f.value().profile, null); assert.equal(f.value().isAuthenticated, false);
  await act(async () => { view.unmount(); });
});

test('refreshing a token for the same user does not discard an in-flight profile', async () => {
  const f = fixture(); let view;
  await act(async () => { view = create(React.createElement(f.exports.UserProfileProvider, null, React.createElement(f.Capture))); });
  await act(async () => { f.emit('SIGNED_IN', session('a')); await wait(); });
  await act(async () => { f.emit('TOKEN_REFRESHED', session('a')); await wait(); });
  assert.equal(f.requests.length, 1);
  await act(async () => { f.requests[0].resolve({ id: 'member-a' }); await f.requests[0].promise; });
  assert.equal(f.value().profile.id, 'member-a');
  await act(async () => { view.unmount(); });
});

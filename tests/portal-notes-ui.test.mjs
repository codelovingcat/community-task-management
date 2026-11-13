import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {runInNewContext} from 'node:vm';
import React from 'react';
import {act,create} from 'react-test-renderer';
import ts from 'typescript';
const require=createRequire(import.meta.url);
const note={id:'n1',owner_id:'a',title:'Önceliğim',body:'<b>plain text</b>',priority:'high',created_at:'2026-11-13T00:00:00Z',updated_at:'2026-11-13T00:00:00Z'};
function load(store) {
 const exports={};const code=ts.transpileModule(readFileSync(new URL('../apps/member-portal/src/Notes.tsx',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX}}).outputText;
 runInNewContext(code,{exports,console,Date,Error,require:key=>key==='react'?React:key==='react/jsx-runtime'?require(key):store});return exports.Notes;
}
const text=view=>JSON.stringify(view.toJSON());
const button=(view,label)=>view.root.findAllByType('button').find(b=>b.children.includes(label));
test('note CRUD persists, deletion requires confirmation, failures preserve draft and double submit is suppressed',async()=>{
 let rows=[note],writes=0,deletes=0,fail=true,release;
 const store={notePageSize:24,listNotes:async()=>rows,saveNote:async(owner,draft)=>{writes++;assert.equal(owner,'a');if(fail)throw new Error('Not kaydedilemedi');await new Promise(r=>release=r);rows=[{...note,...draft}];return rows[0];},deleteNote:async()=>{deletes++;rows=[];}};
 const Notes=load(store);let view;await act(async()=>{view=create(React.createElement(Notes,{ownerId:'a'}));});
 assert.match(text(view),/plain text/);assert.equal(view.root.findAllByType('b').length,0);
 await act(async()=>button(view,'Düzenle').props.onClick());
 await act(async()=>view.root.findByType('textarea').props.onChange({target:{value:'Yeni içerik'}}));
 await act(async()=>view.root.findByType('form').props.onSubmit({preventDefault(){}}));
 assert.match(text(view),/Not kaydedilemedi/);assert.equal(view.root.findByType('textarea').props.value,'Yeni içerik');assert.doesNotMatch(text(view),/Not kaydedildi/);
 fail=false;
 await act(async()=>{view.root.findByType('form').props.onSubmit({preventDefault(){}});view.root.findByType('form').props.onSubmit({preventDefault(){}});});
 assert.equal(writes,2);await act(async()=>release());assert.match(text(view),/Not kaydedildi/);assert.match(text(view),/Yeni içerik/);
 await act(async()=>button(view,'Sil').props.onClick());assert.equal(deletes,0);
 await act(async()=>button(view,'İptal').props.onClick());assert.equal(deletes,0);
 await act(async()=>button(view,'Sil').props.onClick());await act(async()=>button(view,'Evet, notu sil').props.onClick());assert.equal(deletes,1);assert.match(text(view),/Henüz notunuz yok/);
 await act(async()=>view.unmount());
});
test('a failed list can retry and an old account response never populates the new account',async()=>{
 let release,fail=true;
 const store={notePageSize:24,listNotes:owner=>owner==='a'?new Promise(r=>release=r):fail?Promise.reject(new Error('Notlar yüklenemedi')):Promise.resolve([])};
 const Notes=load(store);let view;await act(async()=>{view=create(React.createElement(Notes,{key:'a',ownerId:'a'}));});
 await act(async()=>view.update(React.createElement(Notes,{key:'b',ownerId:'b'})));assert.match(text(view),/Notlar yüklenemedi/);
 await act(async()=>release([note]));assert.doesNotMatch(text(view),/Önceliğim/);
 fail=false;await act(async()=>button(view,'Notları yenile').props.onClick());assert.match(text(view),/Henüz notunuz yok/);
 await act(async()=>view.unmount());
});

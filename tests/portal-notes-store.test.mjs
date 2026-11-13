import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';
import ts from 'typescript';
function fixture(response) {
 const calls=[];const query={};for(const name of ['select','insert','update','delete','eq','order','range'])query[name]=(...args)=>{calls.push([name,...args]);return query;};query.maybeSingle=async()=>response;query.then=(resolve,reject)=>Promise.resolve(response).then(resolve,reject);
 const exports={};const code=ts.transpileModule(readFileSync(new URL('../apps/member-portal/src/notesStore.ts',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText;
 runInNewContext(code,{exports,require:()=>({client:{from:()=>query}})});return {store:exports,calls};
}
const note={id:'n',owner_id:'a',title:'Title',body:'Body',priority:'normal',updated_at:'2026-11-13T00:00:00Z'};
test('create captures owner and updates/deletes use owner and optimistic version filters',async()=>{
 let f=fixture({data:note,error:null});await f.store.saveNote('a',note);assert.equal(f.calls.find(c=>c[0]==='insert')[1].owner_id,'a');
 for(const method of ['saveNote','deleteNote']) {
  f=fixture({data:note,error:null});await (method==='saveNote'?f.store.saveNote('a',note,note):f.store.deleteNote('a',note));
  for(const [column,value] of [['id','n'],['owner_id','a'],['updated_at',note.updated_at]])assert.ok(f.calls.some(c=>c[0]==='eq'&&c[1]===column&&c[2]===value));
 }
});
test('zero-row writes and backend failures are not reported as successful; invalid drafts make no request',async()=>{
 for(const response of [{data:null,error:null},{data:null,error:{message:'denied'}}]) {
  const f=fixture(response);await assert.rejects(f.store.saveNote('a',note,note));await assert.rejects(f.store.deleteNote('a',note));
 }
 const f=fixture({data:note,error:null});await assert.rejects(f.store.saveNote('a',{...note,title:' '}));assert.equal(f.calls.length,0);
});

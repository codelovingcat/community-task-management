import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { runInNewContext } from 'node:vm';
import React from 'react';
import { act, create } from 'react-test-renderer';
import ts from 'typescript';
const require = createRequire(import.meta.url);
function modules(search = '', client = {}) {
  const cache = {};
  function load(name) {
    if (cache[name]) return cache[name];
    const extension = ['taskTiming', 'usePortalSession'].includes(name) ? 'ts' : 'tsx';
    const code = ts.transpileModule(readFileSync(new URL(`../apps/member-portal/src/${name}.${extension}`, import.meta.url),'utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX}}).outputText;
    const exports = {}; cache[name]=exports;
    runInNewContext(code,{exports, console, Date, URL, URLSearchParams, Intl, setInterval,clearInterval,setTimeout,clearTimeout, window:{location:{search}}, require:key=>{
      if(key==='react')return React;
      if(key==='react/jsx-runtime')return require(key);
      if(key==='./client')return {client};
      return load(key.replace('./',''));
    }}); return exports;
  }
  return load;
}
const data={member:{id:'A',name:'Deniz Test',email:'deniz@example.invalid',phone:'555',job_title:'Geliştirici'},tasks:[
  {id:'t1',title:'Anketi incele',description:'Anket sorularını değerlendir',status:'backlog',deadline:'2020-01-01T00:00:00Z'},
  {id:'t2',title:'Etkinlik planı',status:'done',deadline:null}
]};
test('dashboard has separate task groups and no mutation controls; motion and search work',async()=>{
 const {Dashboard}=modules('?task=t1')('Dashboard');let view;let refreshes=0;
 await act(async()=>{view=create(React.createElement(Dashboard,{data,onRefresh:()=>refreshes++}));});
 assert.match(JSON.stringify(view.toJSON()),/Anket sorularını değerlendir/);
 assert.equal(view.root.findAllByType('table').length,2);
 assert.ok(view.root.findByProps({role:'img'}).props['aria-label'].includes('2 görev'));
 assert.doesNotMatch(JSON.stringify(view.toJSON()),/Görevi sil|Görevi düzenle|Görevi tamamla/);
 const checkbox=view.root.findByProps({type:'checkbox'});
 await act(async()=>checkbox.props.onChange({target:{checked:false}}));
 assert.equal(view.root.findByProps({className:'dashboard motion-off'}).type,'div');
 await act(async()=>view.root.findByProps({type:'search'}).props.onChange({target:{value:'Etkinlik'}}));
 assert.equal(view.root.findAllByType('table').length,1);
 const refresh=view.root.findAllByType('button').find(b=>b.children.includes('Bilgileri yenile'));
 await act(async()=>refresh.props.onClick());assert.equal(refreshes,1);
 await act(async()=>view.unmount());
});
test('unowned task URL cannot select another record and empty state has no invalid chart',async()=>{
 const {Dashboard}=modules('?task=not-owned')('Dashboard');let view;
 await act(async()=>{view=create(React.createElement(Dashboard,{data:{...data,tasks:[]},onRefresh(){}}));});
 assert.match(JSON.stringify(view.toJSON()),/Görev bulunamadı/);
 assert.doesNotMatch(JSON.stringify(view.toJSON()),/NaN|Infinity/);
 assert.equal(view.root.findAllByType('table').length,0);
 await act(async()=>view.unmount());
});
test('changing profile key discards old RPC responses and never renders the previous account',async()=>{
 let resolveOld;let calls=0;
 const client={rpc:()=>++calls===1?new Promise(resolve=>{resolveOld=resolve;}):Promise.resolve({data:{...data,member:{...data.member,id:'B',name:'Member B'},tasks:[]},error:null})};
 const {Profile}=modules('',client)('Profile');let view;
 await act(async()=>{view=create(React.createElement(Profile,{key:'A'}));});
 await act(async()=>{view.update(React.createElement(Profile,{key:'B'}));});
 assert.match(JSON.stringify(view.toJSON()),/Member B/);
 await act(async()=>{resolveOld({data,error:null});});
 assert.match(JSON.stringify(view.toJSON()),/Member B/);
 assert.doesNotMatch(JSON.stringify(view.toJSON()),/Deniz Test/);
 await act(async()=>view.unmount());
});

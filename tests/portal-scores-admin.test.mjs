import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {runInNewContext} from 'node:vm';
import React from 'react';
import {act,create} from 'react-test-renderer';
import ts from 'typescript';
const require=createRequire(import.meta.url);
function fixture(role,rpc) {
 const exports={};const code=ts.transpileModule(readFileSync(new URL('../src/components/members/MemberScores.tsx',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX}}).outputText;
 const deps={react:React,'react/jsx-runtime':require('react/jsx-runtime'),'../../lib/supabase':{supabase:{rpc}},'../../context/UserProfileContext':{useUserProfile:()=>({user:{id:'admin'},profile:{system_role:role}})}};
 runInNewContext(code,{exports,require:key=>deps[key]});return exports.MemberScores;
}
test('only administrators request the score table; errors can retry',async()=>{
 for(const role of ['User','Leader',null]) {let calls=0;const C=fixture(role,()=>{calls++;});let view;await act(async()=>{view=create(React.createElement(C));});assert.equal(calls,0);assert.equal(view.toJSON(),null);view.unmount();}
 for(const role of ['Admin','Super Admin']) {
  let calls=0;const C=fixture(role,async()=>++calls===1?{error:{message:'offline'}}:{data:[{member_id:'a',member_name:'Member A',total_points:17,completed_tasks:2}],error:null});let view;
  await act(async()=>{view=create(React.createElement(C));});assert.match(JSON.stringify(view.toJSON()),/Puanlar yüklenemedi/);
  await act(async()=>view.root.findByType('button').props.onClick());assert.match(JSON.stringify(view.toJSON()),/Member A/);assert.equal(view.root.findAllByType('td')[2].children[0],'17');
  await act(async()=>view.unmount());
 }
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {runInNewContext} from 'node:vm';
import React from 'react';
import {act,create} from 'react-test-renderer';
import ts from 'typescript';
import {ticketCode} from '../src/lib/ticketCode.ts';
const require=createRequire(import.meta.url);
const ticket={id:'own',reference:'a0000000-0000-4000-8000-000000000001',state:'valid',registration_state:'confirmed',event_state:'open',title:'Meetup',starts_at:null};
function component(rows,search=''){
 const exports={};const code=ts.transpileModule(readFileSync(new URL('../apps/member-portal/src/Tickets.tsx',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX}}).outputText;
 const deps={react:React,'react/jsx-runtime':require('react/jsx-runtime'),'./client':{client:{rpc:async()=>({data:rows,error:null})}},'../../../src/lib/ticketCode':{ticketCode},'../../../src/components/events/TicketQr':{TicketQr:({value})=>React.createElement('svg',{'data-code':value})}};
 runInNewContext(code,{exports,Date,URLSearchParams,window:{location:{search}},require:k=>deps[k]});return exports.Tickets;
}
test('only usable owned tickets render QR; foreign selector cannot reveal a ticket',async()=>{
 for(const [rows,search,count] of [[[ticket],'',1],[[{...ticket,state:'revoked'}],'',0],[[{...ticket,event_state:'cancelled'}],'',0],[[ticket],'?ticket=foreign',0],[[],'',0]]){
  let v;const C=component(rows,search);await act(async()=>{v=create(React.createElement(C));});assert.equal(v.root.findAllByType('svg').length,count);
  if(search)assert.match(JSON.stringify(v.toJSON()),/size ait değil/);
  await act(async()=>v.unmount());
 }
});

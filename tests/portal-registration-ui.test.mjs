import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {runInNewContext} from 'node:vm';
import React from 'react';
import {act,create} from 'react-test-renderer';
import ts from 'typescript';
const require=createRequire(import.meta.url);
const page={slug:'open-event',title:'Public event',summary:'Details',state:'open',starts_at:'2030-01-01',registration_closes_at:'2030-01-01',privacy_url:'https://example.com/privacy',consent_version:'v1',consent_text:'Consent'};
function load(client){
 const exports={};const code=ts.transpileModule(readFileSync(new URL('../apps/member-portal/src/Registration.tsx',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX}}).outputText;
 const deps={react:React,'react/jsx-runtime':require('react/jsx-runtime'),'./client':{client},'./SignIn':{SignIn:()=>React.createElement('p',null,'Verify email')},'./resourceUrl':{safeResourceUrl:v=>v}};
 runInNewContext(code,{exports,Date,FormData:class{get(k){return k==='name'?'Guest':'on';}},require:k=>deps[k]});return exports.Registration;
}
function clientFor(rpc){const q={select:()=>q,eq:()=>q,maybeSingle:async()=>({data:page,error:null})};return {from:()=>q,rpc};}
test('signed-out registration asks for verification and cannot submit',async()=>{
 const C=load(clientFor(()=>assert.fail()));let v;await act(async()=>{v=create(React.createElement(C,{slug:'open-event',userId:null}));});
 assert.match(JSON.stringify(v.toJSON()),/Verify email/);assert.equal(v.root.findAllByType('form').length,0);v.unmount();
});
test('registration captures identity, prevents double submit and reports full capacity',async()=>{
 let calls=0,resolve,args;const C=load(clientFor((_name,input)=>{calls++;args=input;return new Promise(r=>resolve=r);}));let v;await act(async()=>{v=create(React.createElement(C,{slug:'open-event',userId:'user-a'}));});
 await act(async()=>{const form=v.root.findByType('form');form.props.onSubmit({preventDefault(){},currentTarget:{}});form.props.onSubmit({preventDefault(){},currentTarget:{}});});
 assert.equal(calls,1);assert.equal(args.p_expected_user_id,'user-a');
 await act(async()=>resolve({data:{status:'full'},error:null}));assert.match(JSON.stringify(v.toJSON()),/kontenjanı doldu/);assert.doesNotMatch(JSON.stringify(v.toJSON()),/Kaydınız alındı/);v.unmount();
});

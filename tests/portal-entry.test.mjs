import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {runInNewContext} from 'node:vm';
import React from 'react';
import {act,create} from 'react-test-renderer';
import ts from 'typescript';
import * as links from '../src/lib/portalLinks.ts';
const require=createRequire(import.meta.url);
const id='a0000000-0000-4000-8000-000000000001';
function component(name,auth,window,env={VITE_MEMBER_PORTAL_URL:'https://portal.example.com',DEV:false}) {
 const exports={};const source=readFileSync(new URL('../apps/member-portal/src/'+name+'.tsx',import.meta.url),'utf8').replaceAll('import.meta.env','testEnv');
 const code=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX}}).outputText;
 const deps={react:React,'react/jsx-runtime':require('react/jsx-runtime'),'./client':{client:{auth}},'../../../src/lib/portalLinks':links};
 runInNewContext(code,{exports,window,testEnv:env,URL,FormData:class{constructor(value){this.value=value;}get(key){return this.value[key];}},require:key=>deps[key]});return exports[name];
}
test('return destinations are allowlisted and message links never carry credentials',()=>{
 for(const value of ['https://evil.test','//evil.test','/\\evil.test','/%2f%2fevil.test','/?task=x','/?task='+id+'&next=evil','/register/a?next=evil','/auth/confirm','/\n'])assert.equal(links.safePortalReturn(value),'/');
 for(const value of ['/?task='+id,'/?ticket='+id,'/register/dev-meetup'])assert.equal(links.safePortalReturn(value),value);
 assert.equal(links.portalMessageLink('https://portal.example.com','internal_welcome',id),null);
 assert.equal(links.portalMessageLink('https://portal.example.com','task_assigned',id),'https://portal.example.com/?task='+id);
 assert.equal(links.portalMessageLink('https://portal.example.com','attendee_confirmation',id),'https://portal.example.com/?ticket='+id);
 assert.equal(links.portalAuthRedirect('https://evil.test/path','/'),null);
 assert.equal(links.readPortalConfirmation('https://portal.example.com/auth/confirm?token_hash=untrusted&type=email').token,null);
});
test('confirmation scrubs token, waits for gesture, prevents duplicate consume and returns to task',async()=>{
 let calls=0,resolve,cleaned,destination;
 const window={location:{href:'https://portal.example.com/auth/confirm?next='+encodeURIComponent('/?task='+id)+'#token_hash='+'a'.repeat(64)+'&type=email',replace:value=>destination=value},history:{replaceState:(_a,_b,url)=>cleaned=url}};
 const C=component('AuthConfirm',{verifyOtp:()=>{calls++;return new Promise(r=>resolve=r);}},window);let view;
 await act(async()=>{view=create(React.createElement(C));});assert.equal(calls,0);assert.doesNotMatch(cleaned,/token_hash/);
 await act(async()=>{view.root.findByType('button').props.onClick();view.root.findByType('button').props.onClick();});assert.equal(calls,1);
 await act(async()=>resolve({data:{session:{}},error:null}));assert.equal(destination,'/?task='+id);view.unmount();
});
test('expired token offers safe fresh login',async()=>{
 const window={location:{href:'https://portal.example.com/auth/confirm?next=https://evil.test#token_hash='+'b'.repeat(64)+'&type=email',replace:()=>assert.fail()},history:{replaceState(){}}};
 const C=component('AuthConfirm',{verifyOtp:async()=>({data:{session:null},error:{code:'otp_expired'}})},window);let view;await act(async()=>{view=create(React.createElement(C));});
 await act(async()=>view.root.findByType('button').props.onClick());assert.match(JSON.stringify(view.toJSON()),/süresi dolmuş/);assert.equal(view.root.findByType('a').props.href,'/');view.unmount();
});
test('email entry preserves destination without creating internal accounts',async()=>{
 let input;const window={location:{origin:'https://portal.example.com',pathname:'/',search:'?task='+id}};
 const C=component('SignIn',{signInWithOtp:async args=>{input=args;return {error:null};}},window);let view;await act(async()=>{view=create(React.createElement(C));});
 await act(async()=>view.root.findByType('form').props.onSubmit({preventDefault(){},currentTarget:{email:'a@example.invalid'}}));
 assert.equal(input.options.shouldCreateUser,false);assert.equal(new URL(input.options.emailRedirectTo).searchParams.get('next'),'/?task='+id);assert.match(JSON.stringify(view.toJSON()),/Adresiniz uygunsa/);view.unmount();
});

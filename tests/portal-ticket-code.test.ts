import test from 'node:test';
import assert from 'node:assert/strict';
import qrcode from 'qrcode-generator';
import { ticketCode,parseTicketCode } from '../src/lib/ticketCode';
test('ticket QR encodes only a random reference and cannot be confused with registration URLs',()=>{
 const ref='a0000000-0000-4000-8000-000000000001',code=ticketCode(ref)!;
 assert.equal(parseTicketCode(code),ref);assert.equal(parseTicketCode(ref),ref);
 for(const bad of ['https://portal.example.com/register/event','javascript:bad','ctm-ticket:v2:'+ref,code+'?name=guest','a@example.com',ref+'/extra'])assert.equal(parseTicketCode(bad),null);
 assert.doesNotMatch(code,/email|token|name|https/);
 const qr=qrcode(0,'M');qr.addData(code,'Byte');qr.make();
 assert.ok(qr.getModuleCount()>=21);assert.ok(qr.isDark(0,0));
 assert.match(qr.createDataURL(),/^data:image\/gif;base64,/);
});

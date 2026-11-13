import test from 'node:test';
import assert from 'node:assert/strict';
import { safeResourceUrl } from '../apps/member-portal/src/resourceUrl';
test('portal links allow HTTPS only and never leak credentials or accept control characters',()=>{
 for(const url of ['javascript:alert(1)','http://x.test','https://a:b@x.test','https://x.test/\nx','https://x.test/\\x','https://x.test/'+ 'a'.repeat(2048),'']) assert.equal(safeResourceUrl(url),null);
 assert.equal(safeResourceUrl('https://example.com/survey?q=1'),'https://example.com/survey?q=1');
});

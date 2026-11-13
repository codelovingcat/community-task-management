const reference=/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function ticketCode(value:string):string|null {return reference.test(value)?'ctm-ticket:v1:'+value.toLowerCase():null;}
export function parseTicketCode(value:string):string|null {
 const text=value.trim();const raw=text.startsWith('ctm-ticket:v1:')?text.slice(14):text;
 return reference.test(raw)?raw.toLowerCase():null;
}

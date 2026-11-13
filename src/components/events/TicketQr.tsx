import { useMemo } from 'react';
import qrcode from 'qrcode-generator';
// Entirely local generation: ticket references never leave the application.
export function TicketQr({value,label='QR kod'}:{value:string;label?:string}) {
 const matrix=useMemo(()=>{
  try {const qr=qrcode(0,'M');qr.addData(value,'Byte');qr.make();const n=qr.getModuleCount();let path='';
   for(let y=0;y<n;y++)for(let x=0;x<n;x++)if(qr.isDark(y,x))path+='M'+(x+4)+','+(y+4)+'h1v1h-1z';
   return {size:n+8,path};
  }catch{return null;}
 },[value]);
 if(!matrix)return <p role="status">QR oluşturulamadı. Yazılı kodu kullanabilirsiniz.</p>;
 return <svg role="img" aria-label={label} viewBox={'0 0 '+matrix.size+' '+matrix.size} width="224" height="224" style={{maxWidth:'100%',height:'auto',background:'white'}} shapeRendering="crispEdges"><rect width={matrix.size} height={matrix.size} fill="white"/><path d={matrix.path} fill="black"/></svg>;
}

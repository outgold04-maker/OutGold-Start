import {mkdirSync,writeFileSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {deflateSync} from 'node:zlib';
const root=dirname(fileURLToPath(import.meta.url));
mkdirSync(join(root,'assets'),{recursive:true});
const crcTable=Uint32Array.from({length:256},(_,i)=>{let c=i;for(let j=0;j<8;j++)c=(c&1)?0xedb88320^(c>>>1):c>>>1;return c>>>0});
function crc(buf){let c=0xffffffff;for(const b of buf)c=crcTable[(c^b)&255]^(c>>>8);return (c^0xffffffff)>>>0}
function chunk(type,data){const name=Buffer.from(type),length=Buffer.alloc(4),check=Buffer.alloc(4);length.writeUInt32BE(data.length);check.writeUInt32BE(crc(Buffer.concat([name,data])));return Buffer.concat([length,name,data,check])}
function image(n){const pix=Buffer.alloc(n*(n*4+1));for(let y=0;y<n;y++){const off=y*(n*4+1);pix[off]=0;for(let x=0;x<n;x++){const X=x/n,Y=y/n,cx=X-.5,cy=Y-.5,r=Math.hypot(cx,cy),edge=Math.min(X,Y,1-X,1-Y);let col=[7,28,55,255];
if(edge<.055)col=[13,43,76,255];else if(r<.405&&r>.375)col=[218,178,87,255];else if(r<=.375)col=[247,250,254,255];
const plus=(Math.abs(cx)<.063&&Math.abs(cy)<.23)||(Math.abs(cy)<.063&&Math.abs(cx)<.23);
if(plus)col=[207,28,50,255];
if(r<.37&&r>.32&&!plus)col=[21,92,146,255];
if(cy>.265&&cy<.315&&Math.abs(cx)<.16)col=[218,178,87,255];
const ix=off+1+x*4;pix[ix]=col[0];pix[ix+1]=col[1];pix[ix+2]=col[2];pix[ix+3]=col[3]}}
const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(n,0);ihdr.writeUInt32BE(n,4);ihdr[8]=8;ihdr[9]=6;
return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ihdr),chunk('IDAT',deflateSync(pix,{level:9})),chunk('IEND',Buffer.alloc(0))]);}
for(const n of [192,512])writeFileSync(join(root,'assets','icon-'+n+'.png'),image(n));
console.log('Ícones instaláveis gerados para PWA Central Cajamar');
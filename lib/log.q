.log.o:{
  msg:string[.z.p]," | Info | ",.util.sub x;
  if[.log.write;.log.h msg];
  -1 msg;
 };

.log.e:{
  msg:string[.z.p]," | Error | ",x:.util.sub x;
  if[.log.write;.log.h msg];
  -1 msg;
  'x;
 };
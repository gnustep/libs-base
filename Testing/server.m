#include <objects/stdobjects.h>
#include <stdio.h>
#include <objects/SocketPort.h>
#include <objects/BinaryCStream.h>
#include <objects/Connection.h>
#include <objc/List.h>
#include <objects/String.h>
#include "server.h"

@implementation Server
- init
{
  theList = [[List alloc] init];
  return self;
}
- (unsigned) count
{
  return [theList count];
}
- addObject: o
{
  [theList addObject:o];
  return self;
}
- objectAt: (unsigned)i
{
  return [theList objectAt:i];
}
- print: (const char *)msg
{
  printf(">>%s\n", msg);
  return self;
}
- getLong: (out unsigned long*)i
{
  printf(">>getLong:(out) from client %lu\n", *i);
  *i = 3;
  printf(">>getLong:(out) to client %lu\n", *i);
  return self;
}
- (oneway void) shout
{
  printf(">>Ahhhhh\n");
  return;
}
- callbackNameOn: obj
{
  printf(">>callback name is (%s)\n", [obj name]);
  return self;
}
/* sender must also respond to 'bounce:count:' */
- bounce: sender count: (int)c
{
  if (--c)
    [sender bounce:self count:c];
  return self;
}
- (BOOL) doBoolean: (BOOL)b
{
  printf(">> got boolean '%c' (0x%x) from client\n", b, (unsigned int)b);
  return YES;
}
/* This causes problems, because the runtime encodes this as "*",
   a string! */
- getBoolean: (BOOL*)bp
{
  printf(">> got boolean pointer '%c' (0x%x) from client\n", 
	 *bp, (unsigned int)*bp);
  return self;
}
/* This also causes problems, because the runtime also encodes this as "*",
   a string! */
- getUCharPtr: (unsigned char *)ucp
{
  printf(">> got unsignec char pointer '%c' (0x%x) from client\n", 
	 *ucp, (unsigned int)*ucp);
  return self;
}

/* This isn't working yet */
- (foo*) sendStructPtr: (foo*)f
{
  printf(">>reference: i=%d s=%s l=%lu\n",
	 f->i, f->s, f->l);
  f->i = 88;
  return f;
}
- sendStruct: (foo)f
{
  printf(">>value: i=%d s=%s l=%lu\n",
	 f.i, f.s, f.l);
  f.i = 88;
  return self;
}
- sendSmallStruct: (small_struct)small
{
  printf(">>small value struct: z=%d\n", small.z);
  return self;
}
/* Doesn't work.  GCC __builtin_return doesn't let you return structs? */
- (foo) returnStruct
{
  foo f = {1, "horse", 987654};
  return f;
}
/* Doesn't work because GCC generates the wrong encoding: "@0@+8:+12^i+16" */
- sendArray: (int[3])a
{
  printf(">> array %d %d %d\n", a[0], a[1], a[2]);
  return self;
}
- sendStructArray: (struct myarray)ma
{
  printf(">>struct array %d %d %d\n", ma.a[0], ma.a[1], ma.a[2]);
  return self;
}

- sendDouble: (double)d andFloat: (float)f
{
  printf(">> double %f, float %f\n", d, f);
  return self;
}

- (double*) doDoublePointer: (double*)d
{
  printf(">> got double %f from client\n", *d);
  *d = 1.234567;
  printf(">> returning double %f to client\n", *d);
  return d;
}

- sendCharPtrPtr: (char**)sp
{
  printf(">> got char**, string %s\n", *sp);
  return self;
}

- sendBycopy: (bycopy id)o
{
  printf(">> bycopy class is %s\n", [o name]);
  [o release];
  return self;
}
- manyArgs: (int)i1 : (int)i2 : (int)i3 : (int)i4 : (int)i5 : (int)i6
: (int)i7 : (int)i8 : (int)i9 : (int)i10 : (int)i11 : (int)i12
{
  printf(">> manyArgs: %d %d %d %d %d %d %d %d %d %d %d %d\n",
	 i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, i11, i12);
  return self;
}

- (float) returnFloat
{
  static float f = 2.3456789;
  return f;
}

- (double) returnDouble
{
  /* static <This is crashing gcc ss-940902 config'ed for irix5.1, 
     but running on irix5.2> */
  double d = 4.567891234;
  return d;
}

- senderIsInvalid: anObj
{
  if ([anObj isKindOf:[Connection class]])
    {
      id objList;
      int i, j, count, listCount = [theList count];
      objList = [anObj proxies];
      count = [objList count];
      /* This contortion avoids List's calling -isEqual: on the proxy */
      for (i = 0; i < count; i++)
	for (j = 0; j < [theList count]; j++)
	  if ([theList objectAt:j] == [objList objectAtIndex:i])
	    [theList removeObjectAt:j];
      [objList release];
      if (listCount != [theList count])
	printf("$$$$$ senderIsInvalid: removed from theList\n");
    }
  else
    {
      [self error:"non Connection is invalid"];
    }
  return self;
}
- (Connection*) connection: ancestor didConnect: newConn
{
  printf("%s\n", sel_get_name(_cmd));
  [newConn registerForInvalidationNotification:self];
  [newConn setDelegate:self];
  return newConn;
}
@end

int main()
{
  id l = [[Server alloc] init];
  id o = [[NSObject alloc] init];
  double d;
  Connection *c;

  [BinaryCStream setDebugging:YES];

#if NeXT_runtime
  [Proxy setProtocolForProxies:@protocol(AllProxies)];
#endif
  c = [Connection newRegisteringAtName:@"test2server" withRootObject:l];
  [c registerForInvalidationNotification:l];
  [c setDelegate:l];

  [l addObject:o];
  d = [l returnDouble];
  printf("got double %f\n", d);
  printf("list's hash is 0x%x\n", (unsigned)[l hash]);
  printf("object's hash is 0x%x\n", (unsigned)[o hash]);
  [c runConnection];

  exit(0);
}

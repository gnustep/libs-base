#include <stdio.h>
#include <objects/SocketPort.h>
#include <objects/Connection.h>
#include <objects/Proxy.h>
#include <objects/BinaryCoder.h>
#include <assert.h>
#include "server.h"

int main(int argc, char *argv[])
{
  id p;
  id callback_receiver = [Object new];
  id o;
  id localObj;
  unsigned long i = 4;
  id c;
  int j,k;
  foo f = {99, "cow", 9876543};
  /* foo f2; */
  foo *fp;
  const char *n;
  //  int a3[3] = {66,77,88};
  struct myarray ma = {{55,66,77}};
  double dbl = 3.14159265358979323846264338327;
  double *dbl_ptr;
  char *string = "Hello from the client";
  small_struct small = {12};
  BOOL b;
  const char *type;

  [Coder setDebugging:YES];
  [BinaryCoder setDebugging:YES];

#if NeXT_runtime
  [Proxy setProtocolForProxies:@protocol(AllProxies)];
#endif

  if (argc > 1)
    p = [Connection rootProxyAtName:"test2server" onHost:argv[1]];
  else
    p = [Connection rootProxyAtName:"test2server" onHost:""];
  c = [p connectionForProxy];

  type = [c _typeForSelector:sel_get_any_uid("name") 
	    remoteTarget:[p targetForProxy]];
  printf(">>type = %s\n", type);

  printf(">>list proxy's hash is 0x%x\n", 
	 (unsigned)[p hash]);
  printf(">>list proxy's self is 0x%x = 0x%x\n", 
	 (unsigned)[p self], (unsigned)p);
  n = [p name];
  printf(">>proxy's name is (%s)\n", n);
  [p print:">>This is a message from the client."];
  printf(">>getLong:(out) to server i = %lu\n", i);
  [p getLong:&i];
  printf(">>getLong:(out) from server i = %lu\n", i);
  assert(i == 3);
  o = [p objectAt:0];
  printf(">>object proxy's hash is 0x%x\n", (unsigned)[o hash]);
  [p shout];
  [p callbackNameOn:callback_receiver];
  /* this next line doesn't actually test callbacks, it tests
     sending the same object twice in the same message. */
  [p callbackNameOn:p];
  b = [p doBoolean:YES];
  printf(">>BOOL value is '%c' (0x%x)\n", b, (int)b);
#if 0
  /* Both these cause problems because GCC encodes them as "*",
     indistinguishable from strings. */
  b = NO;
  [p getBoolean:&b];
  printf(">>BOOL reference is '%c' (0x%x)\n", b, (int)b);
  b = NO;
  [p getUCharPtr:&b];
  printf(">>UCHAR reference is '%c' (0x%x)\n", b, (int)b);
#endif
  fp = [p sendStructPtr:&f];
  fp->i = 11;
  [p sendStruct:f];
  [p sendSmallStruct:small];
  [p sendStructArray:ma];
#if 0
  /* returning structures isn't working yet. */
  f2 = [p returnStruct];
  printf(">>returned foo: i=%d s=%s l=%lu\n",
	 f2.i, f2.s, f2.l);
#endif
  [p sendDouble:dbl andFloat:98.6];
  dbl_ptr = [p doDoublePointer:&dbl];
  printf(">>got double %f from server\n", *dbl_ptr);
  [p sendCharPtrPtr:&string];
  /* testing "-perform:" */
  if (p != [p perform:sel_get_any_uid("self")])
    [Object error:"trying perform:"];
  /* testing "bycopy" */
  /* reverse the order on these next two and it doesn't crash,
     however, having manyArgs called always seems to crash.
     Was this problem here before object forward references?
     Check a snapshot. 
     Hmm. It seems like a runtime selector-handling bug. */
  if (![p isProxy])
    [p manyArgs:1 :2 :3 :4 :5 :6 :7 :8 :9 :10 :11 :12];
  [p sendBycopy:callback_receiver];
  printf(">>returned float %f\n", [p returnFloat]);
  printf(">>returned double %f\n", [p returnDouble]);

  localObj = [[Object alloc] init];
  [p addObject:localObj];
  k = [p count];
  for (j = 0; j < k; j++)
    {
      id remote_peer_obj = [p objectAt:j];
      printf("triangle %d object proxy's hash is 0x%x\n", 
	     j, (unsigned)[remote_peer_obj hash]);
      [remote_peer_obj release];
      remote_peer_obj = [p objectAt:j];
      printf("repeated triangle %d object proxy's hash is 0x%x\n", 
	     j, (unsigned)[remote_peer_obj hash]);
    }
  [c runConnectionWithTimeout:1500];
  [c dealloc];

  exit(0);
}

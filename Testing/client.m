#include <stdio.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSDistantObject.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSDate.h>
#include <gnustep/base/Coder.h>
#include <gnustep/base/BinaryCStream.h>
#include <assert.h>
#include "server.h"

int main(int argc, char *argv[])
{
  id a;
  id p;
  id callback_receiver = [NSObject new];
  id o;
  id localObj;
  unsigned long i = 4;
  id c;
  int j,k;
  foo f = {99, "cow", 9876543};
  foo f2;
  small_struct ss;
  foo *fp;
  const char *n;
  int a3[3] = {66,77,88};
  struct myarray ma = {{55,66,77}};
  double dbl = 3.14159265358979323846264338327;
  double *dbl_ptr;
  char *string = "Hello from the client";
  small_struct small = {12};
  BOOL b;
  const char *type;

  [Coder setDebugging:YES];
  [BinaryCStream setDebugging:YES];

#if NeXT_runtime
  [NSDistantObject setProtocolForProxies:@protocol(AllProxies)];
#endif

  if (argc > 1)
    {
      if (argc > 2)
	p = [NSConnection rootProxyAtName: [NSString stringWithCString: argv[2]]
			onHost: [NSString stringWithCString:argv[1]]];
      else
	p = [NSConnection rootProxyAtName:@"test2server"
			onHost:[NSString stringWithCString:argv[1]]];
    }
  else
    p = [NSConnection rootProxyAtName:@"test2server" 
		    onHost:nil];
  c = [p connectionForProxy];
  [c setRequestTimeout:180.0];
  [c setReplyTimeout:180.0];
  localObj = [[NSObject alloc] init];
  [p outputStats:localObj];
  [p getLong:&i];
  [p outputStats:localObj];
  type = [c typeForSelector:sel_get_any_uid("name") 
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
#if 1
  f2 = [p returnStruct];
  printf(">>returned foo: i=%d s=%s l=%lu\n",
	 f2.i, f2.s, f2.l);
  ss = [p returnSmallStruct];
  printf(">>returned ss: %d\n", ss.z);

  f2 = [p returnSetStruct: 99];
  printf(">>returned foo: i=%d s=%s l=%lu\n",
	 f2.i, f2.s, f2.l);
  ss = [p returnSetSmallStruct: 99];
  printf(">>returned ss: %d\n", ss.z);
#endif
  {
    float f = 98.6f;
    printf(">>sending double %f, float %f\n", dbl, f);
    [p sendDouble:dbl andFloat:f];
  }
  dbl_ptr = [p doDoublePointer:&dbl];
  printf(">>got double %f from server\n", *dbl_ptr);
  [p sendCharPtrPtr:&string];
  /* testing "-perform:" */
  if (p != [p perform:sel_get_any_uid("self")])
    [NSObject error:"trying perform:"];
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
#ifdef	_F_BYREF
  [p sendByref:callback_receiver];
  [p sendByref:@"hello"];
  [p sendByref:[NSDate date]];
#endif

  [p addObject:localObj];
  k = [p count];
  for (j = 0; j < k; j++)
    {
      id remote_peer_obj = [p objectAt:j];
      printf("triangle %d object proxy's hash is 0x%x\n", 
	     j, (unsigned)[remote_peer_obj hash]);
      /* xxx look at this again after we use release/retain everywhere */
      if ([remote_peer_obj isProxy])
	[remote_peer_obj release];
      remote_peer_obj = [p objectAt:j];
      printf("repeated triangle %d object proxy's hash is 0x%x\n", 
	     j, (unsigned)[remote_peer_obj hash]);
    }

  [p outputStats:localObj];

  o = [c statistics];
  a = [o allKeys];

  for (j = 0; j < [a count]; j++)
    {
      id k = [a objectAtIndex:j];
      id v = [o objectForKey:k];

      printf("%s - %s\n", [k cString], [[v description] cString]);
    }

  [NSRunLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 20 * 60]];
  [c invalidate];

  exit(0);
}

#include <stdio.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSDistantObject.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSProcessInfo.h>
#include <assert.h>
#include "server.h"

@interface	Auth : NSObject
@end

@implementation	Auth
- (BOOL) authenticateComponents: (NSMutableArray*)components
		       withData: (NSData*)authData
{
  unsigned	count = [components count];

  while (count-- > 0)
    {
      id	obj = [components objectAtIndex: count];

      if ([obj isKindOfClass: [NSData class]] == YES)
	{
	  NSMutableData	*d = [obj mutableCopy];
	  unsigned	l = [d length];
	  char		*p = (char*)[d mutableBytes];

	  while (l-- > 0)
	    p[l] ^= 42;
	  [components replaceObjectAtIndex: count withObject: d];
	  RELEASE(d);
	}
    }
  return YES;
}
@end

int con_data (id prx)
{
  BOOL b;
  unsigned char uc;
  char c;
  short s;
  int i;
  long l;
  float flt = 2.718;
  double dbl = 3.14159265358979323846264338327;
  char *str;
  id obj;
  small_struct small = {12};
  foo ffoo = {99, "cow", 9876543};
  int a3[3] = {66,77,88};
  struct myarray ma = {{55,66,77}};

  printf("Testing data sending\n");
 
  printf("Boolean:\n");
  b = YES;
  printf("  sending %d", b);
  b = [prx sendBoolean: b];
  printf(" got %d\n", b);
  b = YES;
  printf("  sending ptr to %d", b);
  [prx getBoolean: &b];
  printf(" got %d\n", b);

  printf("UChar:\n");
  uc = 23;
  printf("  sending %x", uc);
  uc = [prx sendUChar: uc];
  printf(" got %x\n", uc);
  uc = 24;
  printf("  sending ptr to %x", uc);
  [prx getUChar: &uc];
  printf(" got %x\n", uc);

  printf("Char:\n");
  c = 53;
  printf("  sending %x", c);
  c = [prx sendChar: c];
  printf(" got %x\n", c);
  c = 54;
  printf("  sending ptr to %x", c);
  [prx getChar: &c];
  printf(" got %x\n", c);

  printf("Short:\n");
  s = 23;
  printf("  sending %d", s);
  s = [prx sendShort: s];
  printf(" got %d\n", s);
  s = 24;
  printf("  sending ptr to %d", s);
  [prx getShort: &s];
  printf(" got %d\n", s);

  printf("Int:\n");
  i = 23;
  printf("  sending %d", i);
  i = [prx sendInt: i];
  printf(" got %d\n", i);
  i = 24;
  printf("  sending ptr to %d", i);
  [prx getInt: &i];
  printf(" got %c\n", c);

  printf("Long:\n");
  l = 23;
  printf("  sending %ld", l);
  l = [prx sendLong: l];
  printf(" got %ld\n", l);
  l = 24;
  printf("  sending ptr to %ld", l);
  [prx getLong: &l];
  printf(" got %ld\n", l);

  printf("Float:\n");
  flt = 23;
  printf("  sending %f", flt);
  flt = [prx sendFloat: flt];
  printf(" got %f\n", flt);
  flt = 24;
  printf("  sending ptr to %f", flt);
  [prx getFloat: &flt];
  printf(" got %f\n", flt);

  printf("Double:\n");
  dbl = 23;
  printf("  sending %g", dbl);
  dbl = [prx sendDouble: dbl];
  printf(" got %g\n", dbl);
  dbl = 24;
  printf("  sending ptr to %g", dbl);
  [prx getDouble: &dbl];
  printf(" got %g\n", dbl);

  printf("  >>sending double %f, float %f\n", dbl, flt);
  [prx sendDouble:dbl andFloat:flt];


  printf("String:\n");
  str = "My String 1";
  printf("  sending (%s)", str);
  str = [prx sendString: str];
  printf(" got (%s)\n", str);
  str = "My String 3";
  printf("  sending ptr to (%s)", str);
  [prx getString: &str];
  printf(" got (%s)\n", str);
  
  printf("Small Struct:\n");
  //printf("  sending %x", small.z);
  //small = [prx sendSmallStruct: small];
  //printf(" got %x\n", small.z);
  printf("  sending ptr to %x", small.z);
  [prx getSmallStruct: &small];
  printf(" got %x\n", small.z);

  printf("Struct:\n");
  printf("  sending i=%d,s=%s,l=%ld", ffoo.i, ffoo.s, ffoo.l);
  ffoo = [prx sendStruct: ffoo];
  printf(" got %d %s %ld\n", ffoo.i, ffoo.s, ffoo.l);
  printf("  sending ptr to i=%d,s=%s,l=%ld", ffoo.i, ffoo.s, ffoo.l);
  [prx getStruct: &ffoo];
  printf(" got i=%d,s=%s,l=%ld\n", ffoo.i, ffoo.s, ffoo.l);

  printf("Object:\n");
  obj = [NSObject new];
  printf("  sending %s", [[obj description] cString]);
  obj = [prx sendObject: obj];
  printf(" got %s\n", [[obj description] cString]);
  printf("  sending ptr to %s", [[obj description] cString]);
  [prx getObject: &obj];
  printf(" got %s\n",  [[obj description] cString]);

  return 0;
}

void
usage(const char *program)
{
  printf("Usage: %s [-d -t] [host] [server]\n", program);
  printf("  -d     - Debug connection\n");
  printf("  -t     - Data type test only\n");
}

int main (int argc, char *argv[], char **env)
{
  int c, i, k, j, debug, type_test;
  id a;
  id cobj, prx;
  id obj = [NSObject new];
  id o;
  id localObj;
  const char *n;
  NSAutoreleasePool	*arp;
  Auth *auth;
  extern int optind;
  extern char *optarg;

  [NSProcessInfo initializeWithArguments: argv count: argc environment: env];
  arp = [NSAutoreleasePool new];
  auth = [Auth new];
  GSDebugAllocationActive(YES);

  debug = 0;
  type_test = 0;
  while ((c = getopt(argc, argv, "hdt")) != EOF)
    switch (c) 
      {
      case 'd':
	debug = 1;
	break;
      case 't':
	type_test = 1;
	break;
      case 'h':
	usage(argv[0]);
	exit(0);
	break;
      default:
	usage(argv[0]);
	exit(1);
	break;
      }

  if (debug)
    {
      [NSConnection setDebug: 10];
      [NSDistantObject setDebug: 10];
      //[NSPort setDebug: 10];
    }

#if NeXT_runtime
  [NSDistantObject setProtocolForProxies:@protocol(AllProxies)];
#endif

  if (optind < argc)
    {
      if (optind+1 < argc)
	prx = [NSConnection rootProxyForConnectionWithRegisteredName: 
			      [NSString stringWithCString: argv[optind+1]]
			host: [NSString stringWithCString:argv[optind]]];
      else
	prx = [NSConnection rootProxyForConnectionWithRegisteredName:
			     @"test2server"
			host:[NSString stringWithCString:argv[optind]]];
    }
  else
    prx = [NSConnection rootProxyForConnectionWithRegisteredName:@"test2server" 
		    host:nil];

  if (prx == nil)
    {
      printf("ERROR: Failed to connect to server\n");
      return -1;
    }

  cobj = [prx connectionForProxy];
  [cobj setDelegate:auth];
  [cobj setRequestTimeout:180.0];
  [cobj setReplyTimeout:180.0];
  localObj = [[NSObject alloc] init];
  [prx outputStats:localObj];
  printf(">>list proxy's hash is 0x%x\n", 
	 (unsigned)[prx hash]);
  printf(">>list proxy's self is 0x%x = 0x%x\n", 
	 (unsigned)[prx self], (unsigned)prx);
  n = [prx name];
  printf(">>proxy's name is (%s)\n", n);


  [prx print:">>This is a message from the client.<<"];

  con_data (prx);
  if (type_test)
    return 0;

  o = [prx objectAt:0];
  printf("  >>object proxy's hash is 0x%x\n", (unsigned)[o hash]);
  [prx shout];

  /* this next line doesn't actually test callbacks, it tests
     sending the same object twice in the same message. */
  printf("  >>send same object twice in message\n");
  [prx sendObject: prx];



  printf("performSelector:\n");
  if (prx != [prx performSelector:sel_get_any_uid("self")])
    printf("  ERROR\n");
  else
    printf("  ok\n");


  /* testing "bycopy" */
  /* reverse the order on these next two and it doesn't crash,
     however, having manyArgs called always seems to crash.
     Was this problem here before object forward references?
     Hmm. It seems like a runtime selector-handling bug. */
  printf("many Arguments:\n");
  [prx manyArgs:1 :2 :3 :4 :5 :6 :7 :8 :9 :10 :11 :12];


  printf("Testing bycopy/byref:\n");
  [prx sendBycopy: obj];

#ifdef	_F_BYREF
  [prx sendByref: obj];
  [prx sendByref:@"hello"];
  [prx sendByref:[NSDate date]];
#endif

  [prx addObject:localObj];
  k = [prx count];
  for (j = 0; j < k; j++)
    {
      id remote_peer_obj = [prx objectAt:j];
      printf("triangle %d object proxy's hash is 0x%x\n", 
	     j, (unsigned)[remote_peer_obj hash]);

#if 0
      /* xxx look at this again after we use release/retain everywhere */
      if ([remote_peer_obj isProxy])
	[remote_peer_obj release];
#endif
      remote_peer_obj = [prx objectAt:j];
      printf("repeated triangle %d object proxy's hash is 0x%x\n", 
	     j, (unsigned)[remote_peer_obj hash]);
    }

  [prx outputStats:localObj];

  o = [cobj statistics];
  a = [o allKeys];

  for (j = 0; j < [a count]; j++)
    {
      id k = [a objectAtIndex:j];
      id v = [o objectForKey:k];

      printf("%s - %s\n", [k cString], [[v description] cString]);
    }

  {
    NSDate	  *d = [NSDate date];
    NSMutableData *sen = [NSMutableData data];
    id		rep;

    [sen setLength: 100000];
    rep = [prx sendObject: sen];
    printf("Send: 0x%p, Reply: 0x%p, Length: %d\n", sen, rep, [rep length]);
    if (debug)
      {
	[NSConnection setDebug: 0];
	[NSDistantObject setDebug: 0];
	//[NSPort setDebug: 0];
      }
    for (i = 0; i < 10000; i++)
      {
#if 0
	k = [prx count];
	for (j = 0; j < k; j++)
	  {
	    id remote_peer_obj = [prx objectAt: j];
	  }
#endif
	[prx sendObject: localObj];
      }
      
    printf("Delay is %f\n", [d timeIntervalSinceNow]);
  }

  [arp release];

  arp = [NSAutoreleasePool new];
  printf("%d\n", [cobj retainCount]);
  printf("%s\n", [[[cobj statistics] description] cString]);
//  printf("%s\n", GSDebugAllocationList(YES));

  [NSRunLoop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 20 * 60]];
  [cobj invalidate];
  [arp release];
  return 0;
}

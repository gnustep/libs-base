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
#include <Foundation/NSException.h>
#include <assert.h>
#include "server.h"

#include "wgetopt.h"

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
  BOOL b, br;
  unsigned char uc, ucr;
  char c, cr;
  short s, sr;
  int i, ir;
  long l, lr;
  float flt, fltr;
  double dbl, dblr;
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
  br = [prx sendBoolean: b];
  printf(" got %d", br);
  if (b == !br)
    printf(" ...ok\n");
  else
    printf(" *** ERROR ***\n");
  br = b = YES;
  printf("  sending ptr to %d", br);
  [prx getBoolean: &br];
  printf(" got %d", br);
  if (b == !br)
    printf(" ...ok\n");
  else
    printf(" *** ERROR ***\n");
  printf("  error is ok (due to incorrect encoding by gcc)\n");

#define TEST_CALL(test, send, got, sendp, var, varr, val, msg1, msg2)	\
  printf(test);								\
  var = val;								\
  printf(send, var);							\
  varr = [prx msg1 var];						\
  printf(got, varr);							\
  if (varr != (var+ADD_CONST))					\
    printf(" *** ERROR ***\n");						\
  else									\
    printf(" ...ok\n");							\
  varr = var = val+1;							\
  printf(sendp, varr);							\
  [prx msg2 &varr];							\
  printf(got, varr);							\
  if (varr != (var+ADD_CONST))					\
    printf(" *** ERROR ***\n");						\
  else									\
    printf(" ...ok\n");

#define TEST_FCALL(test, send, got, sendp, var, varr, val, msg1, msg2)	\
  printf(test);								\
  var = val;								\
  printf(send, var);							\
  varr = [prx msg1 var];						\
  printf(got, varr);							\
  if (varr - (var+ADD_CONST) > 1e-3)					\
    printf(" *** ERROR ***\n");						\
  else									\
    printf(" ...ok\n");							\
  varr = var = val+1;							\
  printf(sendp, varr);							\
  [prx msg2 &varr];							\
  printf(got, varr);							\
  if (varr - (var+ADD_CONST) > 1e-3)					\
    printf(" *** ERROR ***\n");						\
  else									\
    printf(" ...ok\n");

  TEST_CALL("UChar:\n", "  sending %d", " got %d", "  sending ptr to %d",
	    uc, ucr, 23, sendUChar:, getUChar:)
  printf("  error is ok (due to incorrect encoding by gcc)\n");

  TEST_CALL("Char:\n", "  sending %d", " got %d", "  sending ptr to %d",
	    c, cr, 23, sendChar:, getChar:)
  printf("  error is ok (due to incorrect encoding by gcc)\n");

  TEST_CALL("Short:\n", "  sending %hd", " got %hd", "  sending ptr to %hd",
	    s, sr, 23, sendShort:, getShort:)

  TEST_CALL("Int:\n", "  sending %d", " got %d", "  sending ptr to %d",
	    i, ir, 23, sendInt:, getInt:)

  TEST_CALL("Long:\n", "  sending %ld", " got %ld", "  sending ptr to %ld",
	    l, lr, 23, sendLong:, getLong:)

  TEST_FCALL("Float:\n", "  sending %f", " got %f", "  sending ptr to %f",
	    flt, fltr, 23.2, sendFloat:, getFloat:)

  TEST_FCALL("Double:\n", "  sending %g", " got %g", "  sending ptr to %g",
	    dbl, dblr, 23.2, sendDouble:, getDouble:)

  flt = 2.718;
  dbl = 3.14159265358979323846264338327;
  printf("  sending double %f, float %f\n", dbl, flt);
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
  [prx addObject: obj];  // FIXME: Why is this needed?
  printf("  sending %s", [[obj description] cString]);
  obj = [prx sendObject: obj];
  printf(" got %s\n", [[obj description] cString]);
  printf("  sending ptr to %s", [[obj description] cString]);
  [prx getObject: &obj];
  printf(" got %s\n",  [[obj description] cString]);

  printf("Many Arguments:\n");
  [prx manyArgs:1 :2 :3 :4 :5 :6 :7 :8 :9 :10 :11 :12];

  return 0;
}

int
con_messages (id prx)
{
  id obj;

  obj = [NSObject new];

  printf("Oneway Void message:\n");
  [prx shout];
  printf("  ok\n");

  printf("Testing exception in method with return value:\n");
  NS_DURING
    {
      [prx exceptionTest1];
      printf("  ERROR\n");
    }
  NS_HANDLER
    {
      printf("  ok ... %s\n", [[localException description] cString]);
    }
  NS_ENDHANDLER

  printf("Testing exception in method with void return:\n");
  NS_DURING
    {
      [prx exceptionTest2];
      printf("  ERROR\n");
    }
  NS_HANDLER
    {
      printf("  ok ... %s\n", [[localException description] cString]);
    }
  NS_ENDHANDLER

  printf("Testing exception in oneway void method:\n");
  NS_DURING
    {
      [prx exceptionTest3];
      printf("  ok\n");
    }
  NS_HANDLER
    {
      printf("  ERROR ... %s\n", [[localException description] cString]);
    }
  NS_ENDHANDLER

  /* this next line doesn't actually test callbacks, it tests
     sending the same object twice in the same message. */
  printf("Send same object twice in message\n");
  [prx sendObject: prx];
  printf("  ok\n");

  printf("performSelector:\n");
  if (prx != [prx performSelector:sel_get_any_uid("self")])
    printf("  ERROR\n");
  else
    printf("  ok\n");

  printf("Testing bycopy/byref:\n");
  [prx sendBycopy: obj];

#ifdef	_F_BYREF
  [prx sendByref: obj];
  [prx sendByref: @"hello"];
  [prx sendByref: [NSDate date]];
  {
    NSMutableString	*str = [NSMutableString string];

    [prx modifyByref: str];
    printf("  Modified '%s'\n", [str lossyCString]);
  }
#endif
  printf("  ok\n");

  return 0;
}

int
con_benchmark (id prx)
{
  int i;
  NSDate	  *d = [NSDate date];
  NSMutableData *sen = [NSMutableData data];
  id localObj;
  id rep;
  
  printf("Benchmarking\n");
  [sen setLength: 100000];
  rep = [prx sendObject: sen];
  printf("  Sent: 0x%p, Reply: 0x%p, Length: %d\n", sen, rep, [rep length]);

  localObj = [[NSObject alloc] init];
  [prx addObject: localObj];  // FIXME: Why is this needed?
  for (i = 0; i < 10000; i++)
    {
#if 0
      k = [prx count];
      for (j = 0; j < k; j++)
	{
	  id remote_peer_obj = [prx objectAt: j];
	}
#endif
      [prx echoObject: localObj];
    }
  
  printf("  Delay is %f\n", [d timeIntervalSinceNow]);
  return 0;
}

int
con_statistics (id prx)
{
  int j;
  id localObj, cobj, a, o;

  printf("------------------------------------------------------------\n");
  printf("Printing Statistics\n");
  localObj = [[NSObject alloc] init];
  [prx outputStats: localObj];
  printf("  >>list proxy's hash is 0x%d\n", [prx hash]);
  printf("  >>list proxy's self is 0x%p = 0x%p\n", [prx self], prx);
  printf("  >>proxy's name is (%s)\n", [prx name]);

  cobj = [prx connectionForProxy];
  o = [cobj statistics];
  a = [o allKeys];

  for (j = 0; j < [a count]; j++)
    {
      id k = [a objectAtIndex:j];
      id v = [o objectForKey:k];

      printf("  %s - %s\n", [k cString], [[v description] cString]);
    }
  printf("------------------------------------------------------------\n");

  return 0;
}

int
con_loop (id prx)
{
  NSAutoreleasePool *arp;
  id cobj;

  arp = [NSAutoreleasePool new];
  cobj = [prx connectionForProxy];
  printf("%d\n", [cobj retainCount]);
  printf("%s\n", [[[cobj statistics] description] cString]);
  //printf("%s\n", GSDebugAllocationList(YES));

  [[NSRunLoop currentRunLoop] runUntilDate:
    [NSDate dateWithTimeIntervalSinceNow: 2 * 60]];
  [cobj invalidate];
  [arp release];
  return 0;
}

int
con_objects (id prx)
{
  int j, k;
  id localObj;

  localObj = [NSObject new];
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
  return 0;
}

void
usage(const char *program)
{
  printf("Usage: %s [-ds] [t|b|m|l|o] [host] [server]\n", program);
  printf("  -d     - Debug connection\n");
  printf("  -s     - Print Statistics\n");
  printf("  -t     - Data type test [default]\n");
  printf("  -b     - Benchmark test\n");
  printf("  -m     - Messaging test\n");
  printf("  -l     - Loop test\n");
  printf("  -o     - Objects test\n");
  printf("  -c     - Connect test\n");
}

typedef enum {
  NO_TEST, TYPE_TEST, BENCHMARK_TEST, MESSAGE_TEST,
  LOOP_TEST, OBJECT_TEST, CONNECT_TEST
} test_t;

int main (int argc, char *argv[], char **env)
{
  int c, debug, stats;
  test_t type_test;
  id cobj, prx;
  unsigned	connect_attempts;
  NSAutoreleasePool	*arp;
  Auth *auth;
#ifndef __MINGW__
  extern int optind;
  extern char *optarg;
#endif

  [NSProcessInfo initializeWithArguments: argv count: argc environment: env];
  arp = [NSAutoreleasePool new];
  auth = [Auth new];
  GSDebugAllocationActive(YES);

  debug = 0;
  type_test = 0;
  stats = 0;
  while ((c = getopt(argc, argv, "hdtbmsloc")) != EOF)
    switch (c) 
      {
      case 'd':
	debug = 1;
	break;
      case 't':
	type_test = TYPE_TEST;
	break;
      case 'b':
	type_test = BENCHMARK_TEST;
	break;
      case 'm':
	type_test = MESSAGE_TEST;
	break;
      case 's':
	stats = 1;
	break;
      case 'l':
	type_test = LOOP_TEST;
	break;
      case 'o':
	type_test = OBJECT_TEST;
	break;
      case 'c':
	type_test = CONNECT_TEST;
	break;
      case 'h':
	usage(argv[0]);
	exit(0);
	break;
      default:
#if 0
	usage(argv[0]);
	exit(1);
#endif
	break;
      }
  if (type_test == NO_TEST)
    type_test = TYPE_TEST;

  if (type_test == CONNECT_TEST)
    connect_attempts = 100000;
  else
    connect_attempts = 1;

  while (connect_attempts-- > 0)
    {
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
	prx = [NSConnection rootProxyForConnectionWithRegisteredName:
		@"test2server" host: @"*"];
      if (prx == nil)
	{
	  printf("ERROR: Failed to connect to server\n");
	  return -1;
	}
      if (type_test == CONNECT_TEST)
	{
	  NSLog(@"Made connection\n");
	  if (connect_attempts > 0)
	    {
	      RELEASE(arp);
	      arp = [NSAutoreleasePool new];
	    }
	}
    }

  cobj = [prx connectionForProxy];
  [cobj setDelegate:auth];
  [cobj setRequestTimeout:180.0];
  [cobj setReplyTimeout:180.0];

  [prx print: "This is a message from the client. Starting Tests!"];

  switch (type_test)
    {
    case TYPE_TEST:
      con_data (prx);
      break;
    case BENCHMARK_TEST:
      con_benchmark (prx);
      break;
    case MESSAGE_TEST:
      con_messages (prx);
      break;
    case LOOP_TEST:
      con_loop (prx);
      break;
    case OBJECT_TEST:
      con_objects (prx);
      break;
    default:
      break;
    }

  if (stats)
    con_statistics (prx);

  [arp release];
  return 0;
}

/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/
#include <Foundation/Foundation.h>
#include <GNUstepBase/GCObject.h>
#include <GNUstepBase/GSMime.h>
#include <stdio.h>


#if 1

static void uncaught(NSException* e)
{
  fprintf(stderr, "In uncaught exception handler.\n");
  [NSException raise: NSGenericException format: @"Recursive exception"];
}

static void test1(void)
{
    NSURL *baseURL = [NSURL fileURLWithPath:@"/usr/local/bin"];
    NSURL *url = [NSURL URLWithString:@"filename" relativeToURL:baseURL];
    NSString *result = [url absoluteString];
    NSString *expected = @"file://localhost/usr/local/bin/filename";

    if ([result isEqualToString:expected])
        NSLog(@"test 1 ok");
    else
        NSLog(@"-[NSURL absoluteString] returned \"%@\", expected \"%@\"", result, expected);
}

static void test2(void)
{
    NSURL *url = [NSURL fileURLWithPath:@"/tmp/foo"];
    NSString *result = [url path];
    NSString *expected = @"/tmp/foo";

    if ([result isEqualToString:expected])
        NSLog(@"Test 2 ok");
    else
        NSLog(@"-[NSURL path] returned \"%@\", expected \"%@\"", result, expected);
}

static try(GSMimeParser *p, NSData *d)
{
  if ([p parse: d] == NO)
    {
      NSLog(@"HTTP parse failure - %@", p);
    }
  else
    {
      BOOL		complete = [p isComplete];
      GSMimeDocument	*document = [p mimeDocument];

      if (complete == NO && [p isInHeaders] == NO)
	{
	  NSString	*enc;
	  NSString	*len;
	  int		ver;

	  ver = [[[document headerNamed: @"http"]
	    objectForKey: NSHTTPPropertyServerHTTPVersionKey] intValue];
	  len = [[document headerNamed: @"content-length"] value];
	  enc = [[document headerNamed: @"content-transfer-encoding"] value];
	  if (enc == nil)
	    {
	      enc = [[document headerNamed: @"transfer-encoding"] value];
	    }

	  if ([enc isEqualToString: @"chunked"] == YES)	
	    {
	      complete = NO;	// Read chunked body data
	    }
	  else if (ver >= 1 && [len intValue] == 0)
	    {
	      complete = YES;	// No content
	    }
	  else
	    {
	      complete = NO;	// No
	    }
	}
      if (complete == YES)
	{
	  NSLog(@"Got data %@", [p data]);
	}
    }
}

int main ()
{
extern char *gnustep_base_version;
  id	pool = [NSAutoreleasePool new];
  id	o = [NSObject new];
  id	x;
  NSString	*s;
  NSArray	*a = [NSArray arrayWithObjects: @"a", @"b", nil];
  struct aa {char a; double b; char c;} bb[2];
  struct objc_struct_layout layout;
  unsigned i;

  NSLog(@"GNUstep Base version: %s", gnustep_base_version);
  fwprintf(stderr, L"This is a test %@\n", @"Hello");

  NSLog(@"Orig: %@", [NSUserDefaults userLanguages]);
  [NSUserDefaults setUserLanguages: [NSArray arrayWithObject: @"Bletch"]];
  NSLog(@"Set: %@", [NSUserDefaults userLanguages]);
  [NSUserDefaults setUserLanguages: [NSArray arrayWithObject: @"English"]];
  NSLog(@"Set: %@", [NSUserDefaults userLanguages]);

  printf("size = %d\n", objc_sizeof_type(@encode(struct aa)));
  printf("pos = %d\n", (void*)&bb[1] - (void*)&bb[0]);

  objc_layout_structure (@encode(struct aa), &layout);
  while (objc_layout_structure_next_member (&layout))
    {
      int position, align;
      const char *type;

      objc_layout_structure_get_info (&layout, &position, &align, &type);
      printf ("element %d has offset %d, alignment %d\n",
              i++, position, align);
    }



  o = [GCMutableArray new];
  x = [GCMutableArray new];
  [o addObject: x];
  [x addObject: o];
  [o release];
  [x release];
  [GCObject gcCollectGarbage];

  o = [NSDictionary dictionaryWithObjectsAndKeys:
   @"test", @"one",
   [NSNumber numberWithBool: YES], @"two",
   [NSDate date], @"three",
   [NSNumber numberWithInt: 33], @"four",
   [NSNumber numberWithFloat: 4.5], @"five",
   nil];
  s = [o description];
  NSLog(@"%@", s);
  x = [s propertyList];
  NSLog(@"%d", [o isEqual: x]);


    test1();
    test2();

  printf ("Hello from object at 0x%x\n", (unsigned)[o self]);

  NS_DURING
    {
      NSLog(@"Value for foo is %@", [a valueForKey: @"foo"]);
    }
  NS_HANDLER
    {
      NSLog(@"Caught expected exception: %@", localException);
    }
  NS_ENDHANDLER

  [o release];
  o = [NSString stringWithFormat: @"/proc/%d/status", getpid()];
  NSLog(@"'%@'", o);
  o = [NSString stringWithContentsOfFile: o];
  NSLog(@"'%@'", o);

  NSLog(@"This test should now cause program termination after a recursive exception");

  NSSetUncaughtExceptionHandler(uncaught);
  [NSException raise: NSGenericException format: @"an artifical exception"];
  exit (0);
}
#else
int main (int argc, char **argv)
{
  NSString *string;
  id	pool = [NSAutoreleasePool new];
  NSProcessInfo	*info = [NSProcessInfo processInfo];
  NSUserDefaults	*defaults;

  NSLog(@"Temporary directory - %@", NSTemporaryDirectory());
  [info setProcessName: @"TestProcess"];
  defaults = [NSUserDefaults standardUserDefaults];
  NSLog(@"%@", [defaults  dictionaryRepresentation]);
  return 0;
}
#endif

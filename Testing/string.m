#include <Foundation/NSString.h>
#include <Foundation/NSException.h>

// Fri Oct 23 02:58:47 MET DST 1998 	dave@turbocat.de
// cStringNoCopy -> cString

/* For demo of Strings as Collections of char's. */
#include <Foundation/NSString.h>
#include    <Foundation/NSAutoreleasePool.h>

void
print_string(NSString* s)
{
  printf("The string [%s], length %d\n", [s cString], [s length]);
}

#include <Foundation/NSString.h>
#include <Foundation/NSGeometry.h>


int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  id s = @"This is a test string";
  id s2, s3;
  int a;
  unichar	uc[6] = { '1', '2', '.', '3', '4', 0};

  NSMutableString	*fo = [NSMutableString stringWithString: @"abcdefg"];
  NS_DURING
  [fo replaceCharactersInRange: [fo rangeOfString: @"xx"] withString: @"aa"];
  NS_HANDLER
    printf("Caught exception during string replacement (expected)\n");
  NS_ENDHANDLER 

  print_string(s);

  s2 = NSStringFromPoint(NSMakePoint(1.374, 5.100));
  print_string(s2);

  printf("%f", [[NSString stringWithCharacters: uc length: 5] floatValue]);

  s2 = [s copy];
  print_string(s2);
  s3 = [s2 mutableCopy];
  [s2 release];
  s2 = [s3 copy];
  [s3 release];
  [s2 release];

  s2 = [s copyWithZone: NSDefaultMallocZone ()];
  print_string(s2);

  s2 = [s stringByAppendingString:@" with something added"];
  print_string(s2);

  s2 = [s mutableCopy];
  [s2 replaceCharactersInRange:((NSRange){10,4})
      withString:@"changed"];
  print_string(s2);

#if 0
  /* Test the use of the `%@' format directive. */
  s2 = [NSString stringWithFormat: @"foo %@ bar",
		 @"test"];
  print_string(s2);

  for (a = 0; a < 10; a++)
    NSLog(@"A string with precision %d is :%.*@:", a, a, @"String");
#endif

  [arp release];
  exit(0);
}

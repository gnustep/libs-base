#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>

// Fri Oct 23 02:58:47 MET DST 1998 	dave@turbocat.de
// cStringNoCopy -> cString

/* For demo of Strings as Collections of char's. */
#include <Foundation/NSString.h>
#include    <Foundation/NSAutoreleasePool.h>

void
print_string(NSString* s)
{
  printf("The string [%s], length %d\n", [s lossyCString], [s length]);
}

#include <Foundation/NSString.h>
#include <Foundation/NSGeometry.h>


int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  id s = @"This is a test string";
  id s2, s3;
  int a;
  unichar	u0[5] = { 0xFE66, 'a', 'b', 'c', 'd'};
  unichar	u1[6] = { '1', '2', '.', '3', '4', 0xFE66};
  unichar	u2[7] = { 'a', 'b', 0xFE66, 'a', 'b', 'c', 'd'};
  NSString	*us0 = [NSString stringWithCharacters: u0 length: 5];
  NSString	*us1 = [NSString stringWithCharacters: u1 length: 6];
  NSString	*us2 = [NSString stringWithCharacters: u2 length: 7];
  NSMutableString	*fo = [NSMutableString stringWithString: @"abcdef"];
  NSMutableString	*f1 = [NSMutableString stringWithString: @"ab"];
  NSStringEncoding	*encs;

#if 0
{	// GSM test
  unichar	buf[] = { 163, '[', ']', '{', '}', '\\', '^', '|', '~', '_' };
  NSString	*str = [NSString stringWithCharacters: buf
			 length: sizeof(buf)/sizeof(unichar)];
  NSData	*gsm  = [str dataUsingEncoding: NSGSM0338StringEncoding];

  NSLog(@"GSM: %*.*s", [gsm length], [gsm length], [gsm bytes]);
  return 0;
}
#endif

  NS_DURING
  [fo replaceCharactersInRange: [fo rangeOfString: @"xx"] withString: us1];
  NS_HANDLER
    printf("Caught exception during string replacement (expected)\n");
  NS_ENDHANDLER 

  [f1 appendString: us0];
  print_string(f1);
  printf("%d\n", [f1 isEqual: us2]);

  print_string(s);

  s2 = NSStringFromPoint(NSMakePoint(1.374, 5.100));
  print_string(s2);

  printf("%f", [[NSString stringWithCharacters: u1 length: 5] floatValue]);

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

{
  NSMutableString	*base = [@"hello" mutableCopy];
  NSString	*ext = [@"\"\\UFE66???\"" propertyList];
  NSString	*want = [@"\"hello\\UFE66???\"" propertyList];
  int		i;

  [base appendString: ext];
  printf("%u\n", [base length]);
  printf("%u\n", [ext length]);
  printf("%u\n", [want length]);
  for (i = 0; i < 4; i++)
    printf("%x\n", [ext characterAtIndex: i]);
  for (i = 0; i < 9; i++)
    printf("%x,%x\n", [base characterAtIndex: i], [want characterAtIndex: i]);
  
  printf("%u\n", [want isEqual: base]);
  for (i = 0; i < 1000; i++)
    [base appendString: want];
  print_string(base);

  encs = [NSString availableStringEncodings];
  while (*encs != 0)
    printf("Encoding %x\n", *encs++);
}

  [arp release];
  exit(0);
}

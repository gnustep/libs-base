#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>

@interface CustomString : NSString
{
  unichar *characters;
  NSUInteger length;
}
@end

@implementation CustomString

- (id) initWithBytesNoCopy: (void *)c
		    length: (NSUInteger)l
		  encoding: (NSStringEncoding)encoding
	      freeWhenDone: (BOOL)freeWhenDone
{
  if (l > 0)
    {
      if (encoding == NSUnicodeStringEncoding)
	{
	  characters = malloc(l);
	  memcpy(characters, c, l);
	}
      else
	{
	  NSString	*s;

	  s = [[NSString alloc] initWithBytesNoCopy: c
					     length: l
					   encoding: encoding
				       freeWhenDone: freeWhenDone];
	  if (s == nil) return nil;
	  l = [s length] * sizeof(unichar);
	  characters = malloc(l);
	  [s getCharacters: characters];
	  [s release];
	}
    }
  length = l / sizeof(unichar);
  return self;
}

- (void) dealloc
{
  if (characters)
    {
      free(characters);
      characters = NULL;
    }
  [super dealloc];
}

- (NSUInteger) length
{
  return length;
}

- (unichar) characterAtIndex: (NSUInteger)index
{
  return characters[index];
}
@end


int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  unichar	u0 = 'a';
  unichar	u1 = 0xfe66;
  NSMutableString *testObj,*base,*ext,*want;

  test_alloc(@"NSMutableString");
  testObj = [[NSMutableString alloc] initWithCString:"Hello\n"];
  test_NSCoding([NSArray arrayWithObject:testObj]);
  test_NSCopying(@"NSString",@"NSMutableString",
                 [NSArray arrayWithObject:testObj],NO,NO); 
  test_NSMutableCopying(@"NSString",@"NSMutableString",
                        [NSArray arrayWithObject:testObj]);
 
  base = [[NSMutableString alloc] initWithCString:"hello"];
  ext = [@"\"\\UFE66???\"" propertyList];
  want = [@"\"hello\\UFE66???\"" propertyList];
  [base appendString:ext];
  PASS([base length] == 9 && [ext length] == 4
    && [want length] == 9 && [base isEqual:want],
    "We can append a unicode string to a C string");

  PASS([[[NSMutableString alloc] initWithCharacters: &u0 length: 1]
    isKindOfClass: [NSMutableString class]],
    "initWithCharacters:length: creates mutable string for ascii");

  PASS([[[NSMutableString alloc] initWithCharacters: &u1 length: 1]
    isKindOfClass: [NSMutableString class]],
    "initWithCharacters:length: creates mutable string for unicode");

  TEST_EXCEPTION([[NSMutableString stringWithString: @"foo"]
		  			appendString: @"bar"];,
		nil,
		NO,
		"can append to string from NSMutableString +stringWithString:");

  testObj = [@"hello" mutableCopy];
  [testObj replaceCharactersInRange: NSMakeRange(1,1) withString: @"a"];
  PASS([testObj isEqual: @"hallo"],
    "replaceCharactersInRange:withString: works in middle of string");
  [testObj replaceCharactersInRange: NSMakeRange(4,1) withString: @"y"];
  PASS([testObj isEqual: @"hally"],
    "replaceCharactersInRange:withString: works at end of string");

  [testObj setString: @"hello"];
  [testObj replaceCharactersInRange: NSMakeRange(1,1)
			 withString: [CustomString stringWithCString: "a"]];
  PASS([testObj isEqual: @"hallo"],
    "custom string replacement works in middle of string");
  [testObj replaceCharactersInRange: NSMakeRange(4,1)
			 withString: [CustomString stringWithCString: "y"]];
  PASS([testObj isEqual: @"hally"],
    "custom string replacement works at end of string");

  [testObj release];
  [arp release]; arp = nil; 
  return 0;
}

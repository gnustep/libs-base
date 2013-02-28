#import "Testing.h" 
#import "ObjectTesting.h"
#import <Foundation/NSString.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCharacterSet.h>

static BOOL rangesEqual(NSRange r1, NSRange r2)
{
  if (&r1 == &r2) 
    return YES;

  if (r1.length == 0 && r2.length == 0)
    return YES;

  return (r1.length == r2.length && r1.location == r2.location);
}

static void strCompare (char *s0, char *s1, NSComparisonResult ci,
                        NSComparisonResult cs, NSComparisonResult lci, 
			NSComparisonResult lcs, NSRange ra)
{
  NSString *cs0, *cs1, *us0, *us1; /* cstrings and unicode strings */
  NSMutableData *d;
  unichar *b;
  int l;
  int opts;
  char *txt,*type;
  NSComparisonResult want, res;
  cs0 = nil; 
  cs1 = nil; 
  us0 = nil; 
  us1 = nil; 
  
  PASS_RUNS(cs0 = [NSString stringWithCString:s0];
  		 l = [cs0 length];
		 d = [NSMutableData dataWithLength:(l * 2)];
		 b = [d mutableBytes];
		 [cs0 getCharacters:b];
		 us0 = [NSString stringWithCharacters:b length:l];
	  
		 cs1 = [NSString stringWithCString:s1];
		 l = [cs1 length];
		 d = [NSMutableData dataWithLength:(l * 2)];
		 b = [d mutableBytes];
		 [cs1 getCharacters:b];
		 us1 = [NSString stringWithCharacters:b length:l];,
               "create strings for compare is ok");
  opts = NSCaseInsensitiveSearch;
  type =  "case insensitive comparison for";
  switch (ci)
    {
    case NSOrderedAscending:
      txt = "NSOrderedAscending";
      break;
    case NSOrderedDescending:
      txt = "NSOrderedDescending";
      break;
    case NSOrderedSame:
      txt = "NSOrderedSame";
      break;
    default:
      txt = "";
    }
  want = ci;

  res = [cs0 compare:cs1 options:opts range:ra];
  PASS(res == want, "CCString %s '%s' and '%s' %s ", type, s0, s1, txt);
  
  res = [us0 compare:us1 options:opts range:ra];
  PASS(res == want, "UUString %s '%s' and '%s' %s ", type, s0, s1, txt);
  
  res = [us0 compare:cs1 options:opts range:ra];
  PASS(res == want, "UCString %s '%s' and '%s' %s ", type, s0, s1, txt);
  
  res = [cs0 compare:us1 options:opts range:ra];
  PASS(res == want, "CUString %s '%s' and '%s' %s ", type, s0, s1, txt);
  
  opts = 0;
  type =  "case sensitive comparison for";
  switch (cs)
    {
    case NSOrderedAscending:
      txt = "NSOrderedAscending";
      break;
    case NSOrderedDescending:
      txt = "NSOrderedDescending";
      break;
    case NSOrderedSame:
      txt = "NSOrderedSame";
      break;
    }
  want = cs;
  res = [cs0 compare:cs1 options:opts range:ra];
  PASS(res == want, "CCString %s '%s' and '%s' %s ", type, s0, s1, txt);
  
  res = [us0 compare:us1 options:opts range:ra];
  PASS(res == want, "UUString %s '%s' and '%s' %s ", type, s0, s1, txt);
  
  res = [us0 compare:cs1 options:opts range:ra];
  PASS(res == want, "UCString %s '%s' and '%s' %s ", type, s0, s1, txt);
  
  res = [cs0 compare:us1 options:opts range:ra];
  PASS(res == want, "CUString %s '%s' and '%s' %s ", type, s0, s1, txt);

  opts = NSCaseInsensitiveSearch | NSLiteralSearch;
  type =  "case insensitive literal comparison for";
  switch (lci)
    {
    case NSOrderedAscending:
      txt = "NSOrderedAscending";
      break;
    case NSOrderedDescending:
      txt = "NSOrderedDescending";
      break;
    case NSOrderedSame:
      txt = "NSOrderedSame";
      break;
    }
  want = lci;
  res = [cs0 compare:cs1 options:opts range:ra];
  PASS(res == want, "CCString %s '%s' and '%s' %s ", type, s0, s1, txt);
  
  res = [us0 compare:us1 options:opts range:ra];
  PASS(res == want, "UUString %s '%s' and '%s' %s ", type, s0, s1, txt);
  
  res = [us0 compare:cs1 options:opts range:ra];
  PASS(res == want, "UCString %s '%s' and '%s' %s ", type, s0, s1, txt);
  
  res = [cs0 compare:us1 options:opts range:ra];
  PASS(res == want, "CUString %s '%s' and '%s' %s ", type, s0, s1, txt);

  opts = NSLiteralSearch;
  type =  "case sensitive literal comparison for";
  switch (lcs)
    {
    case NSOrderedAscending:
      txt = "NSOrderedAscending";
      break;
    case NSOrderedDescending:
      txt = "NSOrderedDescending";
      break;
    case NSOrderedSame:
      txt = "NSOrderedSame";
      break;
    }
  want = lcs;
  res = [cs0 compare:cs1 options:opts range:ra];
  PASS(res == want, "CCString %s '%s' and '%s' %s ", type, s0, s1, txt);
  
  res = [us0 compare:us1 options:opts range:ra];
  PASS(res == want, "UUString %s '%s' and '%s' %s ", type, s0, s1, txt);
  
  res = [us0 compare:cs1 options:opts range:ra];
  PASS(res == want, "UCString %s '%s' and '%s' %s ", type, s0, s1, txt);
  
  res = [cs0 compare:us1 options:opts range:ra];
  PASS(res == want, "CUString %s '%s' and '%s' %s ", type, s0, s1, txt);

}

static void strRange(char *s0, char *s1, unsigned int opts,
 		     NSRange range, NSRange want)
{
  NSString *cs0, *cs1, *us0, *us1 = nil; /* cstrings and unicode strings */
  NSMutableData *d;
  unichar *b;
  int l;
  NSRange res;
  
  cs0 = nil; 
  cs1 = nil; 
  us0 = nil; 
  us1 = nil; 
  
  PASS_RUNS(cs0 = [NSString stringWithCString:s0];
                 l = [cs0 length];
                 d = [NSMutableData dataWithLength:(l * 2)];
                 b = [d mutableBytes];
                 [cs0 getCharacters:b];
                 us0 = [NSString stringWithCharacters:b length:l];

                 cs1 = [NSString stringWithCString:s1];
                 l = [cs1 length];
                 d = [NSMutableData dataWithLength:(l * 2)];
                 b = [d mutableBytes];
                 [cs1 getCharacters:b];
                 us1 = [NSString stringWithCharacters:b length:l];,
                 "create strings for range is ok");
  
  res = [cs0 rangeOfString:cs1 options:opts range:range];
  PASS(rangesEqual(res,want), "CCString range for '%s' and '%s' is ok",s0,s1);
  
  res = [us0 rangeOfString:us1 options:opts range:range];
  PASS(rangesEqual(res,want), "UUString range for '%s' and '%s' is ok",s0,s1);

  res = [us0 rangeOfString:cs1 options:opts range:range];
  PASS(rangesEqual(res,want), "UCString range for '%s' and '%s' is ok",s0,s1);

  res = [cs0 rangeOfString:us1 options:opts range:range];
  PASS(rangesEqual(res,want), "CUString range for '%s' and '%s' is ok",s0,s1);
}

static void strRangeFromSet(char *s, NSCharacterSet *c, unsigned int o, NSRange range, NSRange want)
{
  NSString *cs0, *cs1, *us0, *us1 = nil; /* cstrings and unicode strings */
  NSMutableData *d;
  unichar *b;
  int l;
  NSRange res;
  
  cs0 = nil; 
  cs1 = nil; 
  us0 = nil; 
  us1 = nil; 
  PASS_RUNS(cs0 = [NSString stringWithCString:s];
                 l = [cs0 length];
                 d = [NSMutableData dataWithLength:(l * 2)];
                 b = [d mutableBytes];
                 [cs0 getCharacters:b];
                 us0 = [NSString stringWithCharacters:b length:l];

                 cs1 = [NSMutableString stringWithCString:s];
                 l = [cs1 length];
                 d = [NSMutableData dataWithLength:(l * 2)];
                 b = [d mutableBytes];
                 [cs1 getCharacters:b];
                 us1 = [NSMutableString stringWithCharacters:b length:l];,
                 "create strings for range");
   
   res = [cs0 rangeOfCharacterFromSet:c options:o range:range];
   PASS(rangesEqual(res,want), "CString range for '%s' is ok",s);

   res = [us0 rangeOfCharacterFromSet:c options:o range:range];
   PASS(rangesEqual(res,want), "UString range for '%s' is ok",s);

   res = [cs1 rangeOfCharacterFromSet:c options:o range:range];
   PASS(rangesEqual(res,want), "MCString range for '%s' is ok",s);

   res = [us1 rangeOfCharacterFromSet:c options:o range:range];
   PASS(rangesEqual(res,want), "MUString range for '%s' is ok",s);
}
static void testLineRange(char *s, NSRange range, NSRange want)
{
  NSRange res;
  NSString *cs0;
  int l;
  
  cs0 = [NSString stringWithCString:s];
  l = [cs0 length];
  res = [cs0 lineRangeForRange:range];
  PASS(rangesEqual(res,want), "lineRangeForRange: with '%s' is ok",s);
}

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSString	*str;
  NSString	*sub;
  char	buf[10];
  
  PASS_EXCEPTION([NSString stringWithUTF8String: 0],
    NSInvalidArgumentException,
    "stringWithUTF8String raises for NULL");

  PASS_EXCEPTION([NSString stringWithCString: 0
    encoding: NSASCIIStringEncoding],
    NSInvalidArgumentException,
    "initWithCString raises for NULL");

  PASS_EXCEPTION([@"Hello" substringWithRange:NSMakeRange(6,4)];,
    NSRangeException,
    "NSString extracting substring with range beyond end of string");
  
  PASS_EXCEPTION([@"Hello" compare: @"Hello" 
                          options:NSLiteralSearch 
			    range:NSMakeRange(4,3)];,
		 NSRangeException,
		 "NSString comparison with range beyond end of string");

  strCompare("hello", "hello", NSOrderedSame, NSOrderedSame, NSOrderedSame,
  	     NSOrderedSame,NSMakeRange(0,5)); 
  strCompare("", "",NSOrderedSame, NSOrderedSame, NSOrderedSame, NSOrderedSame,
  	     NSMakeRange(0,0)); 
  strCompare("hello", "Hello", NSOrderedSame, NSOrderedDescending, NSOrderedSame,
  	     NSOrderedDescending,NSMakeRange(0,5)); 
  strCompare("Hello", "hello", NSOrderedSame, NSOrderedAscending, NSOrderedSame,
  	     NSOrderedAscending, NSMakeRange(0,5)); 
  strCompare("abc", "ab", NSOrderedDescending, NSOrderedDescending, 
             NSOrderedDescending, NSOrderedDescending, NSMakeRange(0,3));
  strCompare("ab", "abc", NSOrderedAscending, NSOrderedAscending, 
             NSOrderedAscending, NSOrderedAscending, NSMakeRange(0,2));
  strCompare("", "a", NSOrderedAscending, NSOrderedAscending, NSOrderedAscending,
  	     NSOrderedAscending, NSMakeRange(0,0));
  strCompare("a", "", NSOrderedDescending, NSOrderedDescending, 
  	     NSOrderedDescending, NSOrderedDescending, NSMakeRange(0,1));
  strCompare("a", "", NSOrderedSame, NSOrderedSame, NSOrderedSame, NSOrderedSame,
             NSMakeRange(0,0));  
  strCompare("Location", "LoCaTiOn", NSOrderedSame, NSOrderedDescending,
             NSOrderedSame, NSOrderedDescending, NSMakeRange(0,8));
  strCompare("1234567890_!@$%^&*()QWERTYUIOP{}ASDFGHJKL:;'ZXCVBNM,./<>?",
             "1234567890_!@$%^&*()qwertyuiop{}asdfghjkl:;'zxcvbnm,./<>?",
	     NSOrderedSame, NSOrderedAscending, NSOrderedSame, 
	     NSOrderedAscending, NSMakeRange(0,57));
  strCompare("1234567890_!@$%^&*()QWERTYUIOP{}ASDFGHJKL:;'ZXCVBNM,./<>?",
             "1234567890_!@$%^&*()qwertyuiop{}asdfghjkl:;'zxcvbnm,./<>",
	     NSOrderedSame, NSOrderedAscending, NSOrderedSame, 
	     NSOrderedAscending, NSMakeRange(0,56));
  strCompare("1234567890_!@$%^&*()QWERTYUIOP{}ASDFGHJKL:;'ZXCVBNM,./<>?",
             "1234567890_!@$%^&*()qwertyuiop{}asdfghjkl:;'zxcvbnm,./<>?",
	     NSOrderedAscending, NSOrderedAscending, NSOrderedAscending,
	     NSOrderedAscending, NSMakeRange(0,56));
  strCompare("abcdefg", "ABCDEFG", NSOrderedSame, NSOrderedDescending,
             NSOrderedSame, NSOrderedDescending, NSMakeRange(0, 7));
  strCompare("abcdefg", "CDE", NSOrderedSame, NSOrderedDescending, 
  	     NSOrderedSame, NSOrderedDescending, NSMakeRange(2,3));
  strCompare("abcdefg", "CDEF", NSOrderedAscending, NSOrderedDescending,
  	     NSOrderedAscending, NSOrderedDescending, NSMakeRange(2,3));
  
  strRange("hello", "hello", NSAnchoredSearch, NSMakeRange(0,5), NSMakeRange(0,5));
  strRange("hello", "hello", NSAnchoredSearch | NSBackwardsSearch, NSMakeRange(0,5), NSMakeRange(0,5));
  strRange("hello", "hElLo", NSLiteralSearch, NSMakeRange(0,5), NSMakeRange(0,0));
  strRange("hello", "hElLo", NSCaseInsensitiveSearch, NSMakeRange(0,5), NSMakeRange(0,5));
  strRange("hello", "hell", NSAnchoredSearch, NSMakeRange(0,5), NSMakeRange(0,4));
  strRange("hello", "hel", NSBackwardsSearch, NSMakeRange(0,5), NSMakeRange(0,3));
  strRange("hello", "he", NSLiteralSearch, NSMakeRange(0,5), NSMakeRange(0,2));
  strRange("hello", "h", NSLiteralSearch, NSMakeRange(0,5), NSMakeRange(0,1));
  strRange("hello", "", NSLiteralSearch, NSMakeRange(0,5), NSMakeRange(0,0));
  strRange("hello", "el", NSLiteralSearch, NSMakeRange(0,5), NSMakeRange(1,2));
  strRange("hello", "el", NSLiteralSearch, NSMakeRange(0,2), NSMakeRange(0,0));
  strRange("hello", "el", NSLiteralSearch, NSMakeRange(2,3), NSMakeRange(0,0));
  strRange("hello", "ell", NSLiteralSearch, NSMakeRange(0,5), NSMakeRange(1,3));
  strRange("hello", "lo", NSLiteralSearch, NSMakeRange(2,3), NSMakeRange(3,2));
  strRange("boaboaboa", "abo", NSLiteralSearch, NSMakeRange(0,9), NSMakeRange(2,3));
  strRange("boaboaboa", "abo", NSBackwardsSearch, NSMakeRange(0,9), NSMakeRange(5,3));
  strRange("boaboaboa", "ABO", NSCaseInsensitiveSearch, NSMakeRange(0,9), NSMakeRange(2,3)); 
  strRange("boaboaboa", "abo", NSCaseInsensitiveSearch | NSBackwardsSearch,
           NSMakeRange(0,9), NSMakeRange(5,3)); 
 
  strRangeFromSet("boaboaboa", 
		  [NSCharacterSet alphanumericCharacterSet],
		  NSCaseInsensitiveSearch | NSBackwardsSearch,
		  NSMakeRange(0,9), NSMakeRange(8,1));

  strRangeFromSet("boaboaboa", 
		  [NSCharacterSet alphanumericCharacterSet],
		  NSCaseInsensitiveSearch | NSBackwardsSearch,
		  NSMakeRange(2,6), NSMakeRange(7,1));

  strRangeFromSet("boaboaboa", 
		  [NSCharacterSet whitespaceCharacterSet],
		  NSCaseInsensitiveSearch | NSBackwardsSearch,
		  NSMakeRange(0,9), NSMakeRange(NSNotFound,0));
  
  strRangeFromSet("boaboaboa", 
		  [NSCharacterSet whitespaceCharacterSet],
		  NSCaseInsensitiveSearch | NSBackwardsSearch,
		  NSMakeRange(2,6), NSMakeRange(NSNotFound,0));
  
  strRangeFromSet("bo boaboa", 
		  [NSCharacterSet whitespaceCharacterSet],
		  NSCaseInsensitiveSearch | NSBackwardsSearch,
		  NSMakeRange(0,9), NSMakeRange(2,1));
  
  strRangeFromSet("bo boaboa", 
		  [NSCharacterSet whitespaceCharacterSet],
		  NSCaseInsensitiveSearch | NSBackwardsSearch,
		  NSMakeRange(2,6), NSMakeRange(2,1));
  
  testLineRange("This is a line of text\n", NSMakeRange(10, 10), NSMakeRange(0, 23));
  testLineRange("This is a line of text\r\n", NSMakeRange(10, 10), NSMakeRange(0, 24));
  testLineRange("This is a line of text\r\r", NSMakeRange(10, 10), NSMakeRange(0, 23));
  
  PASS([@"1.2e3" doubleValue] == 1.2e3, "Simple double conversion works");
  PASS([@"4.5E6" floatValue] == 4.5e6, "Simple float conversion works");

  strcpy(buf, "xxaaaxx");
  str = [[NSString alloc] initWithBytesNoCopy: buf
				       length: 7
				     encoding: NSASCIIStringEncoding
				 freeWhenDone: NO];
  sub = [str substringWithRange: NSMakeRange(2, 3)];
  strcpy(buf, "xxbbbxx");
  PASS_EQUAL(str, @"xxbbbxx", "a no-copy string uses the buffer");
  [str release];
  PASS_EQUAL(sub, @"aaa", "a substring uses its own buffer");
  
  [arp release]; arp = nil;
  return 0;
}

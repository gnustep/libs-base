#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#import <Foundation/NSLocale.h>

#if	defined(GS_USE_ICU)
#define	NSLOCALE_SUPPORTED	GS_USE_ICU
#else
#define	NSLOCALE_SUPPORTED	1 /* Assume Apple support */
#endif

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

  START_SET("NSString + locale")
  
  if (!NSLOCALE_SUPPORTED)
    SKIP("NSLocale not supported\nThe ICU library was not available when GNUstep-base was built")
  
  {
    NSComparisonResult compRes;
    NSRange range;
    NSLocale *german = [[NSLocale alloc] initWithLocaleIdentifier: @"de_DE"];
    
    const unichar EszettChar = 0x00df;
    NSString *EszettStr = [[[NSString alloc] initWithCharacters: &EszettChar
							 length: 1] autorelease];

    NSString *EszettPrefixStr = [EszettStr stringByAppendingString: @"abcdef"];
    NSString *EszettSuffixStr = [@"abcdef" stringByAppendingString: EszettStr];
    NSString *EszettPrefixSuffixStr = [NSString stringWithFormat: @"%@abcdef%@", EszettStr, EszettStr];
    
    // test compare:
    
    compRes = [EszettStr compare: @"Ss"
			 options: NSCaseInsensitiveSearch
			   range: NSMakeRange(0, 1)
			  locale: german];
    PASS(compRes == 0, "Ss compares equal to Eszett character in German locale with"
	 " NSCaseInsensitiveSearch. got %d", (int)compRes);
    
    compRes = [EszettStr compare: @"S"
			 options: 0
			   range: NSMakeRange(0, 1)
			  locale: german];
    PASS(compRes == 1, "Eszett compare: S is NSOrderedDescending. got %d", (int)compRes);
    
    compRes = [EszettStr compare: @"s"
			 options: 0
			   range: NSMakeRange(0, 1)
			  locale: german];
    PASS(compRes == 1, "Eszett compare: s is NSOrderedDescending. got %d", (int)compRes);
    
    // test rangeOfString:
    
    range = [EszettPrefixStr rangeOfString: @"sS"
				   options: NSCaseInsensitiveSearch
				     range: NSMakeRange(0, 7)
				    locale: german];
    
    PASS(NSEqualRanges(range, NSMakeRange(0, 1)), "with NSCaseInsensitiveSearch range of sS"
	 " in <Eszett>abcdef is {0,1}. got {%d,%d}", (int)range.location, (int)range.length);
    
    range = [EszettPrefixStr rangeOfString: @"sS"
				   options: 0
				     range: NSMakeRange(0, 7)
				    locale: german];
    
    PASS(NSEqualRanges(range, NSMakeRange(NSNotFound, 0)), "without NSCaseInsensitiveSearch, "
	 "range of sS in <Eszett>abcdef is {NSNotFound, 0}. got {%d,%d}",
	 (int)range.location, (int)range.length);
    
    range = [EszettPrefixStr rangeOfString: @"sS"
				   options: NSCaseInsensitiveSearch | NSAnchoredSearch | NSBackwardsSearch
				     range: NSMakeRange(0, 7)
				    locale: german];
    
    PASS(NSEqualRanges(range, NSMakeRange(NSNotFound, 0)), "for anchored backwards search, "
	 "range of sS in <Eszett>abcdef is {NSNotFound, 0}. got {%d,%d}",
	 (int)range.location, (int)range.length);

    range = [EszettPrefixStr rangeOfString: @"sS"
				   options: NSCaseInsensitiveSearch | NSAnchoredSearch
				     range: NSMakeRange(0, 7)
				    locale: german];
    
    PASS(NSEqualRanges(range, NSMakeRange(0, 1)), "for anchored forwards search, "
	 "range of sS in <Eszett>abcdef is {0, 1}. got {%d,%d}",
	 (int)range.location, (int)range.length);
    
    range = [EszettSuffixStr rangeOfString: @"sS"
				   options: NSCaseInsensitiveSearch | NSAnchoredSearch | NSBackwardsSearch
				     range: NSMakeRange(0, 7)
				    locale: german];

    PASS(NSEqualRanges(range, NSMakeRange(6, 1)), "for anchored backwards search, "
	 "range of sS in abcdef<Eszett> is {6, 1}. got {%d,%d}",
	 (int)range.location, (int)range.length);
    
    range = [EszettPrefixSuffixStr rangeOfString: @"sS"
					 options: NSCaseInsensitiveSearch 
					   range: NSMakeRange(0, 8)
					  locale: german];
    
    PASS(NSEqualRanges(range, NSMakeRange(0, 1)), "for forward search, "
	 "range of sS in <Eszett>abcdef<Eszett> is {0, 1}. got {%d,%d}",
	 (int)range.location, (int)range.length);    

    range = [EszettPrefixSuffixStr rangeOfString: @"sS"
					 options: NSCaseInsensitiveSearch | NSBackwardsSearch
					   range: NSMakeRange(0, 8)
					  locale: german];
    
    PASS(NSEqualRanges(range, NSMakeRange(7, 1)), "for backward search, "
	 "range of sS in <Eszett>abcdef<Eszett> is {7, 1}. got {%d,%d}",
	 (int)range.location, (int)range.length); 
  }
  

  [arp release]; arp = nil;

  END_SET("NSString + locale")

  return 0;
}

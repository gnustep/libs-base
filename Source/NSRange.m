/* NSRange - range functions

*/

#include <config.h>

#define	IN_NSRANGE_M 1
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSScanner.h>

@class	NSString;

static Class	NSStringClass = 0;
static Class	NSScannerClass = 0;
static SEL	scanIntSel = @selector(scanInt:);
static SEL	scanStringSel = @selector(scanString:intoString:);
static SEL	scannerSel = @selector(scannerWithString:);
static BOOL	(*scanIntImp)(NSScanner*, SEL, int*);
static BOOL	(*scanStringImp)(NSScanner*, SEL, NSString*, NSString**);
static id 	(*scannerImp)(Class, SEL, NSString*);

static inline void
setupCache()
{
  if (NSStringClass == 0)
    {
      NSStringClass = [NSString class];
      NSScannerClass = [NSScanner class];
      scanIntImp = (BOOL (*)(NSScanner*, SEL, int*))
	[NSScannerClass instanceMethodForSelector: scanIntSel];
      scanStringImp = (BOOL (*)(NSScanner*, SEL, NSString*, NSString**))
	[NSScannerClass instanceMethodForSelector: scanStringSel];
      scannerImp = (id (*)(Class, SEL, NSString*))
	[NSScannerClass methodForSelector: scannerSel];
    }
}

NSRange
NSMakeRange(unsigned int location, unsigned int length)
{
  NSRange range;
  unsigned int end = location + length;

  if (end < location || end < length)
    {
      [NSException raise: NSRangeException
                  format: @"Range location + length too great"];
    }
  range.location = location;
  range.length   = length;
  return range;
}

NSRange
NSRangeFromString(NSString* string)
{
  NSScanner	*scanner;
  NSRange	range;

  setupCache();
  scanner = (*scannerImp)(NSScannerClass, scannerSel, string);
  if ((*scanStringImp)(scanner, scanStringSel, @"{", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"location", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"=", NULL)
    && (*scanIntImp)(scanner, scanIntSel, &range.location)
    && (*scanStringImp)(scanner, scanStringSel, @";", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"length", NULL)
    && (*scanStringImp)(scanner, scanStringSel, @"=", NULL)
    && (*scanIntImp)(scanner, scanIntSel, &range.length)
    && (*scanStringImp)(scanner, scanStringSel, @"}", NULL))
    return range;
  else
    return NSMakeRange(0, 0);
}

NSString *
NSStringFromRange(NSRange range)
{
  setupCache();
  return [NSStringClass stringWithFormat: @"{location = %d, length = %d}",
    range.location, range.length];
}


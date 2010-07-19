/* NSLocale.m

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by: Stefan Bidigaray
   Date: June, 2010

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

#import "common.h"
#import "Foundation/NSLocale.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSString.h"
#import "GNUstepBase/GSLock.h"

//
// NSLocale Component Keys
//
NSString * const NSLocaleIdentifier = @"NSLocaleIdentifier";
NSString * const NSLocaleLanguageCode = @"NSLocaleLanguageCode";
NSString * const NSLocaleCountryCode = @"NSLocaleCountryCode";
NSString * const NSLocaleScriptCode = @"NSLocaleScriptCode";
NSString * const NSLocaleVariantCode = @"NSLocaleVariantCode";
NSString * const NSLocaleExemplarCharacterSet = @"NSLocaleExemplarCharacterSet";
NSString * const NSLocaleCalendar = @"NSLocaleCalendar";
NSString * const NSLocaleCollationIdentifier = @"NSLocaleCollationIdentifier";
NSString * const NSLocaleUsesMetricSystem = @"NSLocaleUsesMetricSystem";
NSString * const NSLocaleMeasurementSystem = @"NSLocaleMeasurementSystem";
NSString * const NSLocaleDecimalSeparator = @"NSLocaleDecimalSeparator";
NSString * const NSLocaleGroupingSeparator = @"NSLocaleGroupingSeparator";
NSString * const NSLocaleCurrencySymbol = @"NSLocaleCurrencySymbol";
NSString * const NSLocaleCurrencyCode = @"NSLocaleCurrencyCode";
NSString * const NSLocaleCollatorIdentifier = @"NSLocaleCollatorIdentifier";
NSString * const NSLocaleQuotationBeginDelimiterKey =
  @"NSLocaleQuotationBeginDelimiterKey";
NSString * const NSLocaleAlternateQuotationBeginDelimiterKey =
  @"NSLocaleAlternateQuotationBeginDelimiterKey";
NSString * const NSLocaleAlternateQuotationEndDelimiterKey =
  @"NSLocaleAlternateQuotationEndDelimiterKey";

//
// NSLocale Calendar Keys
//
NSString * const NSGregorianCalendar = @"NSGregorianCalendar";
NSString * const NSBuddhistCalendar = @"NSBuddhistCalendar";
NSString * const NSChineseCalendar = @"NSChineseCalendar";
NSString * const NSHebrewCalendar = @"NSHebrewCalendar";
NSString * const NSIslamicCalendar = @"NSIslamicCalendar";
NSString * const NSIslamicCivilCalendar = @"NSIslamicCivilCalendar";
NSString * const NSJapaneseCalendar = @"NSJapaneseCalendar";
NSString * const NSRepublicOfChinaCalendar = @"NSRepublicOfChinaCalendar";
NSString * const NSPersianCalendar = @"NSPersianCalendar";
NSString * const NSIndianCalendar = @"NSIndianCalendar";
NSString * const NSISO8601Calendar = @"NSISO8601Calendar";

static NSLocale *autoupdatingLocale = nil;
static NSLocale *currentLocale = nil;
static NSLocale *systemLocale = nil;
static NSMutableDictionary *allLocales = nil;
static NSRecursiveLock *classLock = nil;

#if	!defined(HAVE_UCI)
# if	HAVE_UNICODE_ULOC_H
#   define	HAVE_UCI	1
# else
#   define	HAVE_UCI	0
# endif
#endif

#if	HAVE_UNICODE_ULOC_H
# include <unicode/uloc.h>
#endif
#if	HAVE_UNICODE_ULOCDATA_H
# include <unicode/ulocdata.h>
#endif
#if	HAVE_UNICODE_UCURR_H
# include <unicode/ucurr.h>
#endif

#if	HAVE_UCI
//
// ICU Component Keywords
//
static const char * ICUCalendarKeyword = "calendar";
static const char * ICUCollationKeyword = "collation";

static NSLocaleLanguageDirection _ICUToNSLocaleOrientation (ULayoutType layout)
{
  switch (layout)
    {
      case ULOC_LAYOUT_LTR:
        return NSLocaleLanguageDirectionLeftToRight;
      case ULOC_LAYOUT_RTL:
        return NSLocaleLanguageDirectionRightToLeft;
      case ULOC_LAYOUT_TTB:
        return NSLocaleLanguageDirectionTopToBottom;
      case ULOC_LAYOUT_BTT:
        return NSLocaleLanguageDirectionBottomToTop;
      default:
        return NSLocaleLanguageDirectionUnknown;
    }
}

static NSArray *_currencyCodesWithType (uint32_t currType)
{
  NSArray *result;
  NSMutableArray *currencies = [[NSMutableArray alloc] initWithCapacity: 10];
  UErrorCode error = U_ZERO_ERROR;
  UErrorCode status = U_ZERO_ERROR;
  const char *currCode;
  UEnumeration *codes = ucurr_openISOCurrencies (currType, &error);
  if (U_FAILURE(error))
    return nil;

  do
    {
      int32_t strLength;
      currCode = uenum_next (codes, &strLength, &status);
      if (U_FAILURE(status))
        {
          uenum_close (codes);
          return nil;
        }
      [currencies addObject: [NSString stringWithCString: currCode
                                                  length: strLength]];
    } while (NULL != currCode);

  uenum_close (codes);
  result = [NSArray arrayWithArray: currencies];
  RELEASE (currencies);
  return result;
}
#endif

@implementation NSLocale

+ (void) initialize
{
  if (self == [NSLocale class])
    {
      classLock = [GSLazyRecursiveLock new];
    }
}

+ (id) autoupdatingCurrentLocale
{
  // FIXME
  NSLocale *result;

  [classLock lock];
  if (nil == autoupdatingLocale)
    {
    }

  result = RETAIN(autoupdatingLocale);
  [classLock unlock];
  return AUTORELEASE(result);
}

+ (NSArray *) availableLocaleIdentifiers
{
  static NSArray	*available = nil;

#if	GS_USE_ICU == 1
  if (nil == available)
    {
      [classLock lock];
      if (nil == available)
	{
	  NSMutableArray	*array;
	  int32_t 		i;
	  int32_t 		count = uloc_countAvailable ();

	  array = [[NSMutableArray alloc] initWithCapacity: count];

	  for (i = 1; i <= count; ++i)
	    {
	      const char *localeID = uloc_getAvailable (i);

	      [array addObject: [NSString stringWithCString: localeID]];
	    }
	  available = [[NSArray alloc] initWithArray: array];
	  [array release];
	}
      [classLock unlock];
    }
#endif
  return [[available copy] autorelease];
}

+ (NSString *) canonicalLanguageIdentifierFromString: (NSString *) string
{
  // FIXME
  return nil;
}

+ (NSString *) canonicalLocaleIdentifierFromString: (NSString *) string
{
  // FIXME
  return nil;
}

+ (NSLocaleLanguageDirection) characterDirectionForLanguage:
    (NSString *)isoLangCode
{
#if	GS_USE_ICU == 1
  ULayoutType result;
  UErrorCode status = U_ZERO_ERROR;

  result = uloc_getCharacterOrientation ([isoLangCode cString], &status);
  if (U_FAILURE(status) || ULOC_LAYOUT_UNKNOWN == result)
    return NSLocaleLanguageDirectionUnknown;

  return _ICUToNSLocaleOrientation (result);
#else
  return NSLocaleLanguageDirectionLeftToRight;	// FIXME
#endif
}

+ (NSDictionary *) componentsFromLocaleIdentifier: (NSString *) string
{
#if	GS_USE_ICU == 1
  char buffer[ULOC_LANG_CAPACITY];
  int32_t strLength;
  UErrorCode error = U_ZERO_ERROR;
  NSDictionary *result;
  NSMutableDictionary *tmpDict =
    [[NSMutableDictionary alloc] initWithCapacity: 5];

  strLength =
    uloc_getLanguage ([string cString], buffer, ULOC_LANG_CAPACITY, &error);
  if (U_SUCCESS(error))
    {
      [tmpDict setObject: [NSString stringWithCString: buffer length: strLength]
                  forKey: NSLocaleLanguageCode];
    }
  error = U_ZERO_ERROR;

  strLength =
    uloc_getCountry ([string cString], buffer, ULOC_COUNTRY_CAPACITY, &error);
  if (U_SUCCESS(error))
    {
      [tmpDict setObject: [NSString stringWithCString: buffer length: strLength]
                  forKey: NSLocaleCountryCode];
    }
  error = U_ZERO_ERROR;

  strLength =
    uloc_getScript ([string cString], buffer, ULOC_SCRIPT_CAPACITY, &error);
  if (U_SUCCESS(error))
    {
      [tmpDict setObject: [NSString stringWithCString: buffer length: strLength]
                  forKey: NSLocaleScriptCode];
    }
  error = U_ZERO_ERROR;

  strLength =
    uloc_getVariant ([string cString], buffer, ULOC_LANG_CAPACITY, &error);
  if (U_SUCCESS(error))
    {
      [tmpDict setObject: [NSString stringWithCString: buffer length: strLength]
                  forKey: NSLocaleVariantCode];
    }
  error = U_ZERO_ERROR;

  result = [NSDictionary dictionaryWithDictionary: tmpDict];
  RELEASE(tmpDict);
  return result;
#else
  return nil;	// FIXME
#endif
}

+ (id) currentLocale
{
  NSLocale *result;

  [classLock lock];
  if (nil == currentLocale)
    {
#if	GS_USE_ICU == 1
      const char *cLocaleId = uloc_getDefault ();
      NSString *localeId = [NSString stringWithCString: cLocaleId];
      currentLocale = [[NSLocale alloc] initWithLocaleIdentifier: localeId];
#endif
    }
  result = RETAIN(currentLocale);
  [classLock unlock];
  return AUTORELEASE(result);
}

+ (NSArray *) commonISOCurrencyCodes
{
#if	GS_USE_ICU == 1
  return _currencyCodesWithType (UCURR_COMMON | UCURR_NON_DEPRECATED);
#else
  return nil;	// FIXME
#endif
}

+ (NSArray *) ISOCurrencyCodes
{
#if	GS_USE_ICU == 1
  return _currencyCodesWithType (UCURR_ALL);
#else
  return nil;	// FIXME
#endif
}

+ (NSArray *) ISOCountryCodes
{
  static NSArray	*countries = nil;

  if (nil == countries)
    {
      [classLock lock];
      if (nil == countries)
	{
#if	GS_USE_ICU == 1
	  NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity: 10];
	  const char *const *codes = uloc_getISOCountries ();

	  while (codes != NULL)
	    {
	      [array addObject: [NSString stringWithCString: *codes]];
	      ++codes;
	    }
	  countries = [[NSArray alloc] initWithArray: array];
	  [array release];
#endif
	}
    }
  return [[countries copy] autorelease];
}

+ (NSArray *) ISOLanguageCodes
{
  static NSArray	*languages = nil;

  if (nil == languages)
    {
      [classLock lock];
      if (nil == languages)
	{
#if	GS_USE_ICU == 1
	  NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity: 10];
	  const char *const *codes = uloc_getISOCountries ();

	  while (codes != NULL)
	    {
	      [array addObject: [NSString stringWithCString: *codes]];
	      ++codes;
	    }
	  languages = [[NSArray alloc] initWithArray: array];
	  [array release];
#endif
	}
    }
  return [[languages copy] autorelease];
}

+ (NSLocaleLanguageDirection) lineDirectionForLanguage: (NSString *) isoLangCode
{
#if	GS_USE_ICU == 1
  ULayoutType result;
  UErrorCode status = U_ZERO_ERROR;

  result = uloc_getLineOrientation ([isoLangCode cString], &status);
  if (U_FAILURE(status) || ULOC_LAYOUT_UNKNOWN == result)
    return NSLocaleLanguageDirectionUnknown;

  return _ICUToNSLocaleOrientation (result);
#else
  return NSLocaleLanguageDirectionTopToBottom;	// FIXME
#endif
}

+ (NSArray *) preferredLanguages
{
  // FIXME
  return [NSUserDefaults userLanguages];
}

+ (id) systemLocale
{
  // FIXME
  NSLocale *result;

  [classLock lock];
  if (nil == systemLocale)
    {
    }

  result = RETAIN(systemLocale);
  [classLock unlock];
  return AUTORELEASE(result);
}

+ (NSString *) localeIdentifierFromComponents: (NSDictionary *) dict
{
#if	GS_USE_ICU == 1
  char buffer[ULOC_FULLNAME_CAPACITY];
  UErrorCode status = U_ZERO_ERROR;
  const char *language = [[dict objectForKey: NSLocaleLanguageCode] cString];
  const char *script = [[dict objectForKey: NSLocaleScriptCode] cString];
  const char *country = [[dict objectForKey: NSLocaleCountryCode] cString];
  const char *variant = [[dict objectForKey: NSLocaleVariantCode] cString];
  const char *calendar = [[dict objectForKey: NSLocaleCalendar] cString];
  const char *collation = [[dict objectForKey: NSLocaleCollationIdentifier] cString];

#define __TEST_CODE(x) (x ? "_" : ""), (x ? x : "")
  snprintf (buffer, ULOC_FULLNAME_CAPACITY, "%s%s%s%s%s%s%s",
    (language ? language : ""), __TEST_CODE(script),
    __TEST_CODE(country), __TEST_CODE(variant));
#undef __TEST_CODE

  if (calendar)
    {
      uloc_setKeywordValue (ICUCalendarKeyword, calendar, buffer,
        ULOC_FULLNAME_CAPACITY, &status);
    }
  if (collation)
    {
      uloc_setKeywordValue (ICUCollationKeyword, collation, buffer,
        ULOC_FULLNAME_CAPACITY, &status);
    }

  return [NSString stringWithCString: buffer];
#else
  return nil;	// FIXME
#endif
}

+ (NSString *) localeIdentifierFromWindowsLocaleCode: (uint32_t) lcid
{
#if	GS_USE_ICU == 1
  char buffer[ULOC_FULLNAME_CAPACITY];
  UErrorCode status = U_ZERO_ERROR;

  int32_t length =
    uloc_getLocaleForLCID (lcid, buffer, ULOC_FULLNAME_CAPACITY, &status);
  if (U_FAILURE(status))
    return nil;

  return [NSString stringWithCString: buffer length: (NSUInteger)length];
#else
  return nil;	// FIXME
#endif
}

+ (uint32_t) windowsLocaleCodeFromLocaleIdentifier: (NSString *)localeIdentifier
{
#if	GS_USE_ICU == 1
  return uloc_getLCID ([localeIdentifier cString]);
#else
  return 0;	// FIXME
#endif
}

- (NSString *) displayNameForKey: (id) key value: (id) value
{
#if	GS_USE_ICU == 1
  int32_t length;
  unichar buffer[ULOC_FULLNAME_CAPACITY];
  UErrorCode status;
  const char *locale = [[self localeIdentifier] cString];

  length = uloc_getDisplayKeywordValue (locale, [key cString],
    [value cString], (UChar *)buffer, sizeof(buffer)/sizeof(unichar),
    &status);
  if (U_FAILURE(status))
    return nil;

  return [NSString stringWithCharacters: buffer length: (NSUInteger)length];
#else
  return nil;	// FIXME
#endif
}

- (id) initWithLocaleIdentifier: (NSString*)string
{
  NSLocale	*newLocale;
  NSString	*localeId;
#if	GS_USE_ICU == 1
  int32_t	length;
  char cLocaleId[ULOC_FULLNAME_CAPACITY];
  UErrorCode error = U_ZERO_ERROR;

  length = uloc_canonicalize ([string cString], cLocaleId,
    ULOC_FULLNAME_CAPACITY, &error);
  if (U_FAILURE(error))
    {
      [self release];
      return nil;
    }
  localeId = [NSString stringWithCString: cLocaleId length: length];
#else
  localeId = string;
#endif

  [classLock lock];
  if (nil == allLocales)
    {
      allLocales = [[NSMutableDictionary alloc] initWithCapacity: 0];
    }
  newLocale = [allLocales objectForKey: localeId];
  if (nil == newLocale)
    {
      _localeId = [localeId copy];
      [allLocales setObject: self forKey: localeId];
    }
  else
    {
      [self release];
      self = [newLocale retain];
    }
  [classLock unlock];

  return self;
}

- (NSString *) localeIdentifier
{
  return _localeId;
}

- (id) objectForKey: (id) key
{
  // FIXME: this is really messy...
  id result;

  if (key == NSLocaleIdentifier)
    return _localeId;

  if ((result = [_components objectForKey: key]))
    return result;

  if ([_components count] == 0)
    {
      [_components addEntriesFromDictionary:
	[NSLocale componentsFromLocaleIdentifier: [self localeIdentifier]]];
      if ((result = [_components objectForKey: key]))
	return result;
    }
  // FIXME: look up other keywords with uloc_getKeywordValue().

  return nil;
}

- (void) dealloc
{
  RELEASE(_localeId);
  RELEASE(_components);
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)encoder
{
  [encoder encodeObject: _localeId];
}

- (id) initWithCoder: (NSCoder*)decoder
{
  NSString	*s = [decoder decodeObject];

  return [self initWithLocaleIdentifier: s];
}

- (id) copyWithZone: (NSZone *) zone
{
  return RETAIN(self);
}

@end


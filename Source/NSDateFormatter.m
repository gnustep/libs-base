/** Implementation of NSDateFormatter class
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: December 1998

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSDateFormatter class reference</title>
   $Date$ $Revision$
   */

#import "common.h"
#define	EXPOSE_NSDateFormatter_IVARS	1
#import "Foundation/NSArray.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSCalendar.h"
#import "Foundation/NSCalendarDate.h"
#import "Foundation/NSLocale.h"
#import "Foundation/NSTimeZone.h"
#import "Foundation/NSFormatter.h"
#import "Foundation/NSDateFormatter.h"
#import "Foundation/NSCoder.h"

#if defined(HAVE_UNICODE_UDAT_H)
#include <unicode/udat.h>
#endif



#define BUFFER_SIZE 1024

@interface NSDateFormatter (PrivateMethods)
- (void) _resetUDateFormat;
- (void) _setSymbols: (NSArray *) array : (NSInteger) symbol;
- (NSArray *) _getSymbols: (NSInteger) symbol;
@end

static inline NSInteger _NSToUDateFormatStyle (NSDateFormatterStyle style)
{
  switch (style)
    {
      case NSDateFormatterNoStyle:
        return UDAT_NONE;
      case NSDateFormatterShortStyle: 
        return UDAT_SHORT;
      case NSDateFormatterMediumStyle: 
        return UDAT_MEDIUM;
      case NSDateFormatterLongStyle:
        return UDAT_LONG;
      case NSDateFormatterFullStyle: 
        return UDAT_FULL;
    }
  return UDAT_NONE;
}

@implementation NSDateFormatter

static NSDateFormatterBehavior _defaultBehavior = 0;

- (id) init
{
  int length;
  unichar buffer[BUFFER_SIZE];
  unichar *value = buffer;
  NSInteger err;
  
  self = [super init];
  if (self == nil)
    return nil;
  
  _behavior = _defaultBehavior;
  _locale = RETAIN([NSLocale currentLocale]);
  _tz = RETAIN([NSTimeZone defaultTimeZone]);
  
/* According to Apple docs, default behavior is NSDateFormatterBehavior10_4 on
   10.5 and later. Yeah, go figure. */
#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST) && GS_USE_ICU == 1
  err = U_ZERO_ERROR;
  
  length =
    udat_toPattern (_formatter, 0, value, BUFFER_SIZE, &err);
  if (length > BUFFER_SIZE)
    {
      value = NSZoneMalloc ([self zone], sizeof(unichar) * length);
      udat_toPattern (_formatter, 0, value, length, &err);
    }
  
  _dateFormat = [NSString stringWithCharacters: value length: length];
  
  if (length > BUFFER_SIZE)
    NSZoneFree ([self zone], value);
#endif
  
  [self _resetUDateFormat];
  
  return self;
}

- (BOOL) allowsNaturalLanguage
{
  return _allowsNaturalLanguage;
}

- (NSAttributedString*) attributedStringForObjectValue: (id)anObject
				 withDefaultAttributes: (NSDictionary*)attr
{
  return nil;
}

- (id) copyWithZone: (NSZone*)zone
{
  NSDateFormatter	*other = (id)NSCopyObject(self, 0, zone);

  IF_NO_GC(RETAIN(other->_dateFormat));
  return other;
}

- (NSString*) dateFormat
{
  return _dateFormat;
}

- (void) dealloc
{
  RELEASE(_dateFormat);
  RELEASE(_locale);
  RELEASE(_tz);
  [super dealloc];
}

- (NSString*) editingStringForObjectValue: (id)anObject
{
  return [self stringForObjectValue: anObject];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeValuesOfObjCTypes: "@C", &_dateFormat, &_allowsNaturalLanguage];
}

- (BOOL) getObjectValue: (id*)anObject
	      forString: (NSString*)string
       errorDescription: (NSString**)error
{
  NSCalendarDate	*d;

  if ([string length] == 0)
    {
      d = nil;
    }
  else
    {
      d = [NSCalendarDate dateWithString: string calendarFormat: _dateFormat];
    }
  if (d == nil)
    {
      if (_allowsNaturalLanguage)
	{
	  d = [NSCalendarDate dateWithNaturalLanguageString: string];
	}
      if (d == nil)
	{
	  if (error)
	    {
	      *error = @"Couldn't convert to date";
	    }
	  return NO;
	}
    }
  if (anObject)
    {
      *anObject = d;
    }
  return YES;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [aCoder decodeValuesOfObjCTypes: "@C", &_dateFormat, &_allowsNaturalLanguage];
  return self;
}

- (id) initWithDateFormat: (NSString *)format
     allowNaturalLanguage: (BOOL)flag
{
  _dateFormat = [format copy];
  _allowsNaturalLanguage = flag;
  return self;
}

- (BOOL) isPartialStringValid: (NSString*)partialString
	     newEditingString: (NSString**)newString
	     errorDescription: (NSString**)error
{
  if (newString)
    {
      *newString = nil;
    }
  if (error)
    {
      *error = nil;
    }
  return YES;
}

- (NSString*) stringForObjectValue: (id)anObject
{
  if ([anObject isKindOfClass: [NSDate class]] == NO)
    {
      return nil;
    }
  return [anObject descriptionWithCalendarFormat: _dateFormat
					timeZone: [NSTimeZone defaultTimeZone]
					  locale: nil];
}



+ (NSDateFormatterBehavior) defaultFormatterBehavior
{
  return _defaultBehavior;
}

+ (void) setDefaultFormatterBehavior: (NSDateFormatterBehavior) behavior
{
  _defaultBehavior = behavior;
}

- (NSDateFormatterBehavior) formatterBehavior
{
  return _behavior;
}

- (void) setFormatterBehavior: (NSDateFormatterBehavior) behavior
{
  _behavior = behavior;
}

- (BOOL) generatesCalendarDates
{
  return NO;
}

- (void) setGeneratesCalendarDates: (BOOL) flag
{
  return;
}

- (BOOL) isLenient
{
#if GS_USE_ICU == 1
  return (BOOL)udat_isLenient (_formatter);
#else
  return NO;
#endif
}

- (void) setLenient: (BOOL) flag
{
#if GS_USE_ICU == 1
  udat_setLenient (_formatter, flag);
#else
  return;
#endif
}


- (NSDate *) dateFromString: (NSString *) string
{
#if GS_USE_ICU == 1
  NSDate *result = nil;
  UDate date;
  UChar *text;
  int32_t textLength;
  UErrorCode err = U_ZERO_ERROR;
  int32_t pPos = 0;
  
  textLength = [string length];
  text = NSZoneMalloc ([self zone], sizeof(UChar) * textLength);
  if (text == NULL)
    return nil;
  
  [string getCharacters: text range: NSMakeRange (0, textLength)];
  
  date = udat_parse (_formatter, text, textLength, &pPos, &err);
  if (U_SUCCESS(err))
    result =
      [NSDate dateWithTimeIntervalSince1970: (NSTimeInterval)(date / 1000.0)];
  
  NSZoneFree ([self zone], text);
  return result;
#else
  return nil;
#endif
}

- (NSString *) stringFromDate: (NSDate *) date
{
#if GS_USE_ICU == 1
  NSString *result;
  int32_t length;
  unichar buffer[BUFFER_SIZE];
  unichar *string = buffer;
  UErrorCode err = U_ZERO_ERROR;
  
  length = udat_format (_formatter,
                        [date timeIntervalSince1970] * 1000.0,
                        string,
                        BUFFER_SIZE,
                        NULL,
                        &err);
  if (U_FAILURE(err))
    return nil;
  if (length > BUFFER_SIZE)
    {
      string = NSZoneMalloc ([self zone], sizeof(UChar) * length);
      udat_format (_formatter,
                   [date timeIntervalSince1970] * 1000.0,
                   string,
                   length,
                   NULL,
                   &err);
      if (U_FAILURE(err))
        return nil;
    }
  
  result = [NSString stringWithCharacters: string length: length];
  
  if (length > BUFFER_SIZE)
    NSZoneFree ([self zone], string);
  
  return result;
#else
  return nil;
#endif
}

- (BOOL) getObjectValue: (out id *) obj
              forString: (NSString *) string
                  range: (inout NSRange *) range
                  error: (out NSError **) error
{
  return NO;
}

- (void) setDateFormat: (NSString *) string
{
#if GS_USE_ICU == 1
  UChar *pattern;
  int32_t patternLength;
  
  patternLength = [string length];
  pattern = NSZoneMalloc ([self zone], sizeof(UChar) * patternLength);
  [string getCharacters: pattern range: NSMakeRange(0, patternLength)];
  
  udat_applyPattern (_formatter, 0, pattern, patternLength);
  
  NSZoneFree ([self zone], pattern);
#endif
  if (_dateFormat)
    RELEASE(_dateFormat);
  _dateFormat = RETAIN(string);
}

- (NSDateFormatterStyle) dateStyle
{
  return _dateStyle;
}

- (void) setDateStyle: (NSDateFormatterStyle) style
{
  _dateStyle = style;
  [self _resetUDateFormat];
}

- (NSDateFormatterStyle) timeStyle
{
  return _timeStyle;
}

- (void) setTimeStyle: (NSDateFormatterStyle) style
{
  _timeStyle = style;
  [self _resetUDateFormat];
}

- (NSCalendar *) calendar
{
  return nil;
}

- (void) setCalendar: (NSCalendar *) calendar
{
  return;
}

- (NSDate *) defaultDate
{
  return nil;
}

- (void) setDefaultDate: (NSDate *) date
{
  return;
}

- (NSLocale *) locale
{
  return _locale;
}

- (void) setLocale: (NSLocale *) locale
{
  if (locale == _locale)
    return;
  RELEASE(_locale);
  
  _locale = RETAIN(locale);
  [self _resetUDateFormat];
}

- (NSTimeZone *) timeZone
{
  return _tz;
}

- (void) setTimeZone: (NSTimeZone *) tz
{
  if (tz == _tz)
    return;
  RELEASE(_tz);
  
  _tz = RETAIN(tz);
  [self _resetUDateFormat];
}

- (NSDate *) twoDigitStartDate
{
#if GS_USE_ICU == 1
  UErrorCode err = U_ZERO_ERROR;
  return [NSDate dateWithTimeIntervalSince1970:
    (udat_get2DigitYearStart (_formatter, &err) / 1000.0)];
#else
  return nil;
#endif
}

- (void) setTwoDigitStartDate: (NSDate *) date
{
#if GS_USE_ICU == 1
  UErrorCode err = U_ZERO_ERROR;
  udat_set2DigitYearStart (_formatter,
                           ([date timeIntervalSince1970] * 1000.0),
                           &err);
#else
  return;
#endif
}


- (NSString *) AMSymbol
{
  return nil;
}

- (void) setAMSymbol: (NSString *) string
{
  return;
}

- (NSString *) PMSymbol
{
  return nil;
}

- (void) setPMSymbol: (NSString *) string
{
  return;
}

- (NSArray *) weekdaySymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_WEEKDAYS];
#else
  return nil;
#endif
}

- (void) setWeekdaySymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_WEEKDAYS];
#else
  return;
#endif
}

- (NSArray *) shortWeekdaySymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_SHORT_WEEKDAYS];
#else
  return nil;
#endif
}

- (void) setShortWeekdaySymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _getSymbols: UDAT_SHORT_WEEKDAYS];
#else
  return;
#endif
}

- (NSArray *) monthSymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_MONTHS];
#else
  return nil;
#endif
}

- (void) setMonthSymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _getSymbols: UDAT_MONTHS];
#else
  return;
#endif
}

- (NSArray *) shortMonthSymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_SHORT_MONTHS];
#else
  return nil;
#endif
}

- (void) setShortMonthSymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _getSymbols: UDAT_SHORT_MONTHS];
#else
  return;
#endif
}

- (NSArray *) eraSymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_ERAS];
#else
  return nil;
#endif
}

- (void) setEraSymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_ERAS];
#else
  return;
#endif
}

- (NSDate *) gregorianStartDate
{
  return nil;
}

- (void) setGregorianStartDate: (NSDate *) date
{
  return;
}

- (NSArray *) longEraSymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_ERA_NAMES];
#else
  return nil;
#endif
}

- (void) setLongEraSymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_ERA_NAMES];
#else
  return;
#endif
}


- (NSArray *) quarterSymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_QUARTERS];
#else
  return nil;
#endif
}

- (void) setQuarterSymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_QUARTERS];
#else
  return;
#endif
}

- (NSArray *) shortQuarterSymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_SHORT_QUARTERS];
#else
  return nil;
#endif
}

- (void) setShortQuarterSymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_SHORT_QUARTERS];
#else
  return;
#endif
}

- (NSArray *) standaloneQuarterSymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_STANDALONE_QUARTERS];
#else
  return nil;
#endif
}

- (void) setStandaloneQuarterSymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_STANDALONE_QUARTERS];
#else
  return;
#endif
}

- (NSArray *) shortStandaloneQuarterSymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_STANDALONE_SHORT_QUARTERS];
#else
  return nil;
#endif
}

- (void) setShortStandaloneQuarterSymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_STANDALONE_SHORT_QUARTERS];
#else
  return;
#endif
}

- (NSArray *) shortStandaloneMonthSymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_STANDALONE_SHORT_MONTHS];
#else
  return nil;
#endif
}

- (void) setShortStandaloneMonthSymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_STANDALONE_SHORT_MONTHS];
#else
  return;
#endif
}

- (NSArray *) standaloneMonthSymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_STANDALONE_MONTHS];
#else
  return nil;
#endif
}

- (void) setStandaloneMonthSymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_STANDALONE_MONTHS];
#else
  return;
#endif
}

- (NSArray *) veryShortMonthSymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_NARROW_MONTHS];
#else
  return nil;
#endif
}

- (void) setVeryShortMonthSymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_NARROW_MONTHS];
#else
  return;
#endif
}

- (NSArray *) veryShortStandaloneMonthSymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_STANDALONE_NARROW_MONTHS];
#else
  return nil;
#endif
}

- (void) setVeryShortStandaloneMonthSymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_STANDALONE_NARROW_MONTHS];
#else
  return;
#endif
}

- (NSArray *) shortStandaloneWeekdaySymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_STANDALONE_SHORT_WEEKDAYS];
#else
  return nil;
#endif
}

- (void) setShortStandaloneWeekdaySymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_STANDALONE_SHORT_WEEKDAYS];
#else
  return;
#endif
}

- (NSArray *) standaloneWeekdaySymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_STANDALONE_WEEKDAYS];
#else
  return nil;
#endif
}

- (void) setStandaloneWeekdaySymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_STANDALONE_WEEKDAYS];
#else
  return;
#endif
}

- (NSArray *) veryShortWeekdaySymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_SHORT_WEEKDAYS];
#else
  return nil;
#endif
}

- (void) setVeryShortWeekdaySymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_SHORT_WEEKDAYS];
#else
  return;
#endif
}

- (NSArray *) veryShortStandaloneWeekdaySymbols
{
#if GS_USE_ICU == 1
  return [self _getSymbols: UDAT_STANDALONE_NARROW_WEEKDAYS];
#else
  return nil;
#endif
}

- (void) setVeryShortStandaloneWeekdaySymbols: (NSArray *) array
{
#if GS_USE_ICU == 1
  [self _setSymbols: array : UDAT_STANDALONE_NARROW_WEEKDAYS];
#else
  return;
#endif
}

+ (NSString *) localizedStringFromDate: (NSDate *) date
                             dateStyle: (NSDateFormatterStyle) dateStyle
                             timeStyle: (NSDateFormatterStyle) timeStyle
{
  NSString *result;
  NSDateFormatter *fmt = [[self alloc] init];
  
  [fmt setDateStyle: dateStyle];
  [fmt setTimeStyle: timeStyle];
  
  result = [fmt stringFromDate: date];
  RELEASE(fmt);
  
  return result;
}

+ (NSString *) dateFormatFromTemplate: (NSString *) template
                              options: (NSUInteger) opts
                               locale: (NSLocale *) locale
{
  NSString *result;
  NSDateFormatter *fmt = [[self alloc] init];
  
  [fmt setLocale: locale];
  result = [fmt dateFormat];
  RELEASE(fmt);
  
  return result;
}

- (BOOL) doesRelativeDateFormatting
{
  return NO;
}

- (void) setDoesRelativeDateFormatting: (BOOL) flag
{
  return;
}
@end

@implementation NSDateFormatter (PrivateMethods)
- (void) _resetUDateFormat
{
#if GS_USE_ICU == 1
  UChar *tzID;
  int32_t tzIDLength;
  UErrorCode err = U_ZERO_ERROR;
  
  if (_formatter)
    udat_close (_formatter);
  
  tzIDLength = [[_tz name] length];
  tzID = NSZoneMalloc ([self zone], sizeof(UChar) * tzIDLength);
  [[_tz name] getCharacters: tzID range: NSMakeRange (0, tzIDLength)];
  
  _formatter = udat_open (_NSToUDateFormatStyle(_timeStyle),
                          _NSToUDateFormatStyle(_dateStyle),
                          [[_locale localeIdentifier] UTF8String],
                          tzID,
                          tzIDLength,
                          NULL,
                          0,
                          &err);
  if (U_FAILURE(err))
    _formatter = NULL;
  
  NSZoneFree ([self zone], tzID);
#else
  return;
#endif
}

- (void) _setSymbols: (NSArray *) array : (NSInteger) symbol
{
#if GS_USE_ICU == 1
  int idx = 0;
  int count = udat_countSymbols (_formatter, symbol);
  
  if ([array count] != count)
    return;
  
  while (idx < count)
    {
      int length;
      UChar *value;
      UErrorCode err = U_ZERO_ERROR;
      NSString *string = [array objectAtIndex: idx];
      
      length = [string length];
      value = NSZoneMalloc ([self zone], sizeof(unichar) * length);
      [string getCharacters: value range: NSMakeRange(0, length)];
      
      udat_setSymbols (_formatter, symbol, idx, value, length, &err);
      
      NSZoneFree ([self zone], value);
      
      ++idx;
    }
#else
  return;
#endif
}

- (NSArray *) _getSymbols: (NSInteger) symbol
{
#if GS_USE_ICU == 1
  NSMutableArray *mArray;
  int idx = 0;
  int count = udat_countSymbols (_formatter, symbol);
  
  mArray = [NSMutableArray arrayWithCapacity: count];
  while (idx < count)
    {
      int length;
      unichar buffer[BUFFER_SIZE];
      unichar *value = buffer;
      UErrorCode err = U_ZERO_ERROR;
      
      length =
        udat_getSymbols (_formatter, symbol, idx, value, BUFFER_SIZE, &err);
      if (length > BUFFER_SIZE)
        {
          value = NSZoneMalloc ([self zone], sizeof(unichar) * length);
          udat_getSymbols (_formatter, symbol, idx, value, length, &err);
        }
      
      [mArray addObject: [NSString stringWithCharacters: value length: length]];
      
      if (length > BUFFER_SIZE)
        NSZoneFree ([self zone], value);
      
      ++idx;
    }
  
  return [NSArray arrayWithArray: mArray];
#else
  return nil;
#endif
}
@end


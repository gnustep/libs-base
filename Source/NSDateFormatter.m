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

#include <unicode/udat.h>



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
  self = [super init];
  if (self == nil)
    return nil;
  
  _behavior = _defaultBehavior;
  _locale = [NSLocale currentLocale];
  _tz = [NSTimeZone defaultTimeZone];
  
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
#else
  return;
#endif
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
  if (_locale != nil)
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
  if (_tz != nil)
    RELEASE(_tz);
  
  _tz = RETAIN(tz);
  [self _resetUDateFormat];
}

- (NSDate *) twoDigitStartDate
{
  return nil;
}

- (void) setTwoDigitStartDate: (NSDate *) date
{
  return;
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
  return nil;
}

- (void) setWeekdaySymbols: () array
{
  return;
}

- (NSArray *) shortWeekdaySymbols
{
  return nil;
}

- (void) setShortWeekdaySymbols: (NSArray *) array
{
  return;
}

- (NSArray *) monthSymbols
{
  return nil;
}

- (void) setMonthSymbols: (NSArray *) array
{
  return;
}

- (NSArray *) shortMonthSymbols
{
  return nil;
}

- (void) setShortMonthSymbols: (NSArray *) array
{
  return;
}

- (NSArray *) eraSymbols
{
  return nil;
}

- (void) setEraSymbols: (NSArray *) array
{
  return;
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
  return nil;
}

- (void) setLongEraSymbols: (NSArray *) array
{
  return;
}


- (NSArray *) quarterSymbols
{
  return nil;
}

- (void) setQuarterSymbols: (NSArray *) array
{
  return;
}

- (NSArray *) shortQuarterSymbols
{
  return nil;
}

- (void) setShortQuarterSymbols: (NSArray *) array
{
  return;
}

- (NSArray *) standaloneQuarterSymbols
{
  return nil;
}

- (void) setStandaloneQuarterSymbols: (NSArray *) array
{
  return;
}

- (NSArray *) shortStandaloneQuarterSymbols
{
  return nil;
}

- (void) setShortStandaloneQuarterSymbols: (NSArray *) array
{
  return;
}

- (NSArray *) shortStandaloneMonthSymbols
{
  return nil;
}

- (void) setShortStandaloneMonthSymbols: (NSArray *) array
{
  return;
}

- (NSArray *) standaloneMonthSymbols
{
  return nil;
}

- (void) setStandaloneMonthSymbols: (NSArray *) array
{
  return;
}

- (NSArray *) veryShortMonthSymbols
{
  return nil;
}

- (void) setVeryShortMonthSymbols: (NSArray *) array
{
  return;
}

- (NSArray *) veryShortStandaloneMonthSymbols
{
  return nil;
}

- (void) setVeryShortStandaloneMonthSymbols: (NSArray *) array
{
  return;
}

- (NSArray *) shortStandaloneWeekdaySymbols
{
  return nil;
}

- (void) setShortStandaloneWeekdaySymbols: (NSArray *) array
{
  return;
}

- (NSArray *) standaloneWeekdaySymbols
{
  return nil;
}

- (void) setStandaloneWeekdaySymbols: (NSArray *) array
{
  return;
}

- (NSArray *) veryShortWeekdaySymbols
{
  return nil;
}

- (void) setVeryShortWeekdaySymbols: (NSArray *) array
{
  return;
}

- (NSArray *) veryShortStandaloneWeekdaySymbols
{
  return nil;
}

- (void) setVeryShortStandaloneWeekdaySymbols: (NSArray *) array
{
  return;
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
  return nil;
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
  
  return [NSArray arrayWithArray: mArray];;
#else
  return nil;
#endif
}
@end


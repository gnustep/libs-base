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
#if defined(HAVE_UNICODE_UDATPG_H)
#include <unicode/udatpg.h>
#endif



// This is defined to be the same as UDAT_RELATIVE
#define FormatterDoesRelativeDateFormatting (1<<16)
#define BUFFER_SIZE 1024

@interface NSDateFormatter (PrivateMethods)
- (void) _resetUDateFormat;
- (void) _setSymbols: (NSArray *) array : (NSInteger) symbol;
- (NSArray *) _getSymbols: (NSInteger) symbol;
@end

static inline NSInteger _NSToUDateFormatStyle (NSDateFormatterStyle style)
{
#if GS_USE_ICU == 1
  NSInteger relative =
    (style & FormatterDoesRelativeDateFormatting) ? UDAT_RELATIVE : 0;
  switch (style)
    {
      case NSDateFormatterNoStyle:
        return (relative | UDAT_NONE);
      case NSDateFormatterShortStyle: 
        return (relative | UDAT_SHORT);
      case NSDateFormatterMediumStyle: 
        return (relative | UDAT_MEDIUM);
      case NSDateFormatterLongStyle:
        return (relative | UDAT_LONG);
      case NSDateFormatterFullStyle: 
        return (relative | UDAT_FULL);
    }
#endif
  return -1;
}

typedef struct
{
  NSUInteger _behavior;
  NSLocale   *_locale;
  NSTimeZone *_tz;
  NSDateFormatterStyle _timeStyle;
  NSDateFormatterStyle _dateStyle;
  void      *_formatter;
} Internal;

#define this    ((Internal*)(self->_reserved))
#define inst    ((Internal*)(o->_reserved))

@implementation NSDateFormatter

static NSDateFormatterBehavior _defaultBehavior = 0;

- (id) init
{
  self = [super init];
  if (self == nil)
    return nil;
  
  _reserved = NSZoneCalloc([self zone], 1, sizeof(Internal));
  this->_behavior = _defaultBehavior;
  this->_locale = RETAIN([NSLocale currentLocale]);
  this->_tz = RETAIN([NSTimeZone defaultTimeZone]);
  
  [self _resetUDateFormat];
  
/* According to Apple docs, default behavior is NSDateFormatterBehavior10_4 on
   10.5 and later. Yeah, go figure. */
#if GS_USE_ICU == 1
  {
    int length;
    unichar *value;
    NSZone *z = [self zone];
    UErrorCode err = U_ZERO_ERROR;
    
    length = udat_toPattern (this->_formatter, 0, NULL, 0, &err);
    value = NSZoneMalloc (z, sizeof(unichar) * length);
    err = U_ZERO_ERROR;
    udat_toPattern (this->_formatter, 0, value, length, &err);
    if (U_SUCCESS(err))
      {
        _dateFormat = [[NSString allocWithZone: z]
          initWithBytesNoCopy: value
          length: length * sizeof(unichar)
          encoding: NSUnicodeStringEncoding
          freeWhenDone: YES];
      }
    else
      {
        NSZoneFree (z, value);
      }
  }
#endif
  
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
  NSDateFormatter	*o = (id)NSCopyObject(self, 0, zone);

  IF_NO_GC(RETAIN(o->_dateFormat));
  if (0 != this)
    {
      o->_reserved = NSZoneCalloc([self zone], 1, sizeof(Internal));
      memcpy(inst, this, sizeof(Internal));
      IF_NO_GC(RETAIN(inst->_locale);)
#if GS_USE_ICU == 1
      {
        UErrorCode err = U_ZERO_ERROR;
        inst->_formatter = udat_clone (this->_formatter, &err);
      }
#endif
    }
  
  return o;
}

- (NSString*) dateFormat
{
  return _dateFormat;
}

- (void) dealloc
{
  RELEASE(_dateFormat);
  if (this != 0)
    {
      RELEASE(this->_locale);
      RELEASE(this->_tz);
#if GS_USE_ICU == 1
      udat_close (this->_formatter);
#endif
      NSZoneFree([self zone], this);
    }
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
  this->_behavior = NSDateFormatterBehavior10_0;
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
  return this->_behavior;
}

- (void) setFormatterBehavior: (NSDateFormatterBehavior) behavior
{
  this->_behavior = behavior;
}

- (BOOL) generatesCalendarDates
{
  return NO; // FIXME
}

- (void) setGeneratesCalendarDates: (BOOL) flag
{
  return; // FIXME
}

- (BOOL) isLenient
{
#if GS_USE_ICU == 1
  return (BOOL)udat_isLenient (this->_formatter);
#else
  return NO;
#endif
}

- (void) setLenient: (BOOL) flag
{
#if GS_USE_ICU == 1
  udat_setLenient (this->_formatter, flag);
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
  
  date = udat_parse (this->_formatter, text, textLength, &pPos, &err);
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
  unichar *string;
  NSZone *z = [self zone];
  UDate udate = [date timeIntervalSince1970] * 1000.0;
  UErrorCode err = U_ZERO_ERROR;
  
  length = udat_format (this->_formatter, udate, NULL, 0, NULL, &err);
  string = NSZoneMalloc (z, sizeof(UChar) * (length + 1));
  err = U_ZERO_ERROR;
  udat_format (this->_formatter, udate, string, length, NULL, &err);
  if (U_SUCCESS(err))
    {
      result = AUTORELEASE([[NSString allocWithZone: z]
        initWithBytesNoCopy: string
        length: length * sizeof(UChar)
        encoding: NSUnicodeStringEncoding
        freeWhenDone: YES]);
      return result;
    }
  
  NSZoneFree (z, string);
  return nil;
#else
  return nil;
#endif
}

- (BOOL) getObjectValue: (out id *) obj
              forString: (NSString *) string
                  range: (inout NSRange *) range
                  error: (out NSError **) error
{
  return NO; // FIXME
}

- (void) setDateFormat: (NSString *) string
{
#if GS_USE_ICU == 1
  UChar *pattern;
  int32_t patternLength;
  
  patternLength = [string length];
  pattern = NSZoneMalloc ([self zone], sizeof(UChar) * patternLength);
  [string getCharacters: pattern range: NSMakeRange(0, patternLength)];
  
  udat_applyPattern (this->_formatter, 0, pattern, patternLength);
  
  NSZoneFree ([self zone], pattern);
#endif
  if (_dateFormat)
    RELEASE(_dateFormat);
  _dateFormat = RETAIN(string);
}

- (NSDateFormatterStyle) dateStyle
{
  return this->_dateStyle;
}

- (void) setDateStyle: (NSDateFormatterStyle) style
{
  this->_dateStyle = style;
  [self _resetUDateFormat];
}

- (NSDateFormatterStyle) timeStyle
{
  return this->_timeStyle;
}

- (void) setTimeStyle: (NSDateFormatterStyle) style
{
  this->_timeStyle = style;
  [self _resetUDateFormat];
}

- (NSCalendar *) calendar
{
  return [this->_locale objectForKey: NSLocaleCalendar];
}

- (void) setCalendar: (NSCalendar *) calendar
{
  NSMutableDictionary *dict;
  NSLocale *locale;
  
  dict = [[NSLocale componentsFromLocaleIdentifier: [this->_locale localeIdentifier]]
    mutableCopy];
  [dict setValue: calendar forKey: NSLocaleCalendar];
  locale = [[NSLocale alloc] initWithLocaleIdentifier:
    [NSLocale localeIdentifierFromComponents: (NSDictionary *)dict]];
  [self setLocale: locale];
  /* Don't have to use udat_setCalendar here because -setLocale: will take care
     of setting the calendar when it resets the formatter. */
  RELEASE(locale);
  RELEASE(dict);
}

- (NSDate *) defaultDate
{
  return nil;  // FIXME
}

- (void) setDefaultDate: (NSDate *) date
{
  return; // FIXME
}

- (NSLocale *) locale
{
  return this->_locale;
}

- (void) setLocale: (NSLocale *) locale
{
  if (locale == this->_locale)
    return;
  RELEASE(this->_locale);
  
  this->_locale = RETAIN(locale);
  [self _resetUDateFormat];
}

- (NSTimeZone *) timeZone
{
  return this->_tz;
}

- (void) setTimeZone: (NSTimeZone *) tz
{
  if (tz == this->_tz)
    return;
  RELEASE(this->_tz);
  
  this->_tz = RETAIN(tz);
  [self _resetUDateFormat];
}

- (NSDate *) twoDigitStartDate
{
#if GS_USE_ICU == 1
  UErrorCode err = U_ZERO_ERROR;
  return [NSDate dateWithTimeIntervalSince1970:
    (udat_get2DigitYearStart (this->_formatter, &err) / 1000.0)];
#else
  return nil;
#endif
}

- (void) setTwoDigitStartDate: (NSDate *) date
{
#if GS_USE_ICU == 1
  UErrorCode err = U_ZERO_ERROR;
  udat_set2DigitYearStart (this->_formatter,
                           ([date timeIntervalSince1970] * 1000.0),
                           &err);
#else
  return;
#endif
}


- (NSString *) AMSymbol
{
#if GS_USE_ICU == 1
  NSArray *array = [self _getSymbols: UDAT_AM_PMS];
  
  return [array objectAtIndex: 0];
#else
  return nil;
#endif
}

- (void) setAMSymbol: (NSString *) string
{
  return;
}

- (NSString *) PMSymbol
{
#if GS_USE_ICU == 1
  NSArray *array = [self _getSymbols: UDAT_AM_PMS];
  
  return [array objectAtIndex: 1];
#else
  return nil;
#endif
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

+ (NSString *) dateFormatFromTemplate: (NSString *) aTemplate
                              options: (NSUInteger) opts
                               locale: (NSLocale *) locale
{
#if GS_USE_ICU == 1
  unichar pat[BUFFER_SIZE];
  unichar skel[BUFFER_SIZE];
  int32_t patLen;
  int32_t skelLen;
  UDateTimePatternGenerator *datpg;
  UErrorCode err = U_ZERO_ERROR;
  
  datpg = udatpg_open ([[locale localeIdentifier] UTF8String], &err);
  if (U_FAILURE(err))
    return nil;
  
  if ((patLen = [aTemplate length]) > BUFFER_SIZE)
    patLen = BUFFER_SIZE;
  [aTemplate getCharacters: pat range: NSMakeRange(0, patLen)];
  
  skelLen = udatpg_getSkeleton (datpg, pat, patLen, skel, BUFFER_SIZE, &err);
  if (U_FAILURE(err))
    return nil;
  
  patLen =
    udatpg_getBestPattern (datpg, skel, skelLen, pat, BUFFER_SIZE, &err);
  
  udatpg_close (datpg);
  return [NSString stringWithCharacters: pat length: patLen];
#else
  return nil;
#endif
}

- (BOOL) doesRelativeDateFormatting
{
  return (this->_dateStyle & FormatterDoesRelativeDateFormatting) ? YES : NO;
}

- (void) setDoesRelativeDateFormatting: (BOOL) flag
{
  this->_dateStyle |= FormatterDoesRelativeDateFormatting;
}
@end

@implementation NSDateFormatter (PrivateMethods)
- (void) _resetUDateFormat
{
#if GS_USE_ICU == 1
  UChar *tzID;
  int32_t tzIDLength;
  UErrorCode err = U_ZERO_ERROR;
  
  if (this->_formatter)
    udat_close (this->_formatter);
  
  tzIDLength = [[this->_tz name] length];
  tzID = NSZoneMalloc ([self zone], sizeof(UChar) * tzIDLength);
  [[this->_tz name] getCharacters: tzID range: NSMakeRange (0, tzIDLength)];
  
  this->_formatter = udat_open (_NSToUDateFormatStyle(this->_timeStyle),
                          _NSToUDateFormatStyle(this->_dateStyle),
                          [[this->_locale localeIdentifier] UTF8String],
                          tzID,
                          tzIDLength,
                          NULL,
                          0,
                          &err);
  if (U_FAILURE(err))
    this->_formatter = NULL;
  
  NSZoneFree ([self zone], tzID);
#else
  return;
#endif
}

- (void) _setSymbols: (NSArray *) array : (NSInteger) symbol
{
#if GS_USE_ICU == 1
  int idx = 0;
  int count = udat_countSymbols (this->_formatter, symbol);
  
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
      
      udat_setSymbols (this->_formatter, symbol, idx, value, length, &err);
      
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
  int count = udat_countSymbols (this->_formatter, symbol);
  
  mArray = [NSMutableArray arrayWithCapacity: count];
  while (idx < count)
    {
      int length;
      unichar *value;
      NSString *str;
      NSZone *z = [self zone];
      UErrorCode err = U_ERROR_LIMIT;
      
      length = udat_getSymbols (this->_formatter, symbol, idx, NULL, 0, &err);
      value = NSZoneMalloc (z, sizeof(unichar) * (length + 1));
      err = U_ZERO_ERROR;
      udat_getSymbols (this->_formatter, symbol, idx, value, length, &err);
      if (U_SUCCESS(err))
        {
          str = AUTORELEASE([[NSString allocWithZone: z]
            initWithBytesNoCopy: value
            length: length * sizeof(unichar)
            encoding: NSUnicodeStringEncoding
            freeWhenDone: YES]);
          [mArray addObject: str];
        }
      else
        {
          NSZoneFree (z, value);
        }
      
      ++idx;
    }
  
  return [NSArray arrayWithArray: mArray];
#else
  return nil;
#endif
}
@end


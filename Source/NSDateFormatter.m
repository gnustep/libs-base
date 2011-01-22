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
#import "Foundation/NSDate.h"
#import "Foundation/NSCalendarDate.h"
#import "Foundation/NSTimeZone.h"
#import "Foundation/NSFormatter.h"
#import "Foundation/NSDateFormatter.h"
#import "Foundation/NSCoder.h"

@implementation NSDateFormatter

static NSDateFormatterBehavior _defaultBehavior = 0;

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
  return 0;
}

- (void) setFormatterBehavior: (NSDateFormatterBehavior) behavior
{
  return;
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
  return NO;
}

- (void) setLenient: (BOOL) flag
{
  return;
}


- (NSDate *) dateFromString: (NSString *) string
{
  return nil;
}

- (NSString *) stringFromDate: (NSDate *) date
{
  return nil;
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
  return;
}

- (NSDateFormatterStyle) dateStyle
{
  return 0;
}

- (void) setDateStyle: (NSDateFormatterStyle) style
{
  return;
}

- (NSDateFormatterStyle) timeStyle
{
  return 0;
}

- (void) setTimeStyle: (NSDateFormatterStyle) style
{
  return;
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
  return nil;
}

- (void) setLocale: (NSLocale *) locale
{
  return;
}

- (NSTimeZone *) timeZone
{
  return nil;
}

- (void) setTimeZone: (NSTimeZone *) tz
{
  return;
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
  return nil;
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


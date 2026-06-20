/* Interface for NSDateFormatter for GNUStep
   Copyright (C) 1998 Free Software Foundation, Inc.

   Header Written by:  Camille Troillard <tuscland@wanadoo.fr>
   Created: November 1998
   Modified by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#ifndef __NSDateFormatter_h_GNUSTEP_BASE_INCLUDE
#define __NSDateFormatter_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)

#import	<Foundation/NSFormatter.h>

@class NSCalendar, NSLocale, NSArray;

#if	defined(__cplusplus)
extern "C" {
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_4, GS_API_LATEST)
enum
{
  NSDateFormatterNoStyle     = 0,
  NSDateFormatterShortStyle  = 1,
  NSDateFormatterMediumStyle = 2,
  NSDateFormatterLongStyle   = 3,
  NSDateFormatterFullStyle   = 4
};
typedef NSUInteger NSDateFormatterStyle;

enum
{
  NSDateFormatterBehaviorDefault = 0,
  NSDateFormatterBehavior10_0    = 1000,
  NSDateFormatterBehavior10_4    = 1040
};
typedef NSUInteger NSDateFormatterBehavior;
#endif

/**
 *  <p>Class for generating text representations of [NSDate]s and
 *  [NSCalendarDate]s, and for converting strings into instances of these
 *  objects.  Note that [NSDate] and [NSCalendarDate] do contain some
 *  string conversion methods, but using this class provides more control
 *  over conversion.</p>
 *  <p>See the [NSFormatter] documentation for description of the basic methods
 *  for formatting and parsing that are available.</p>
 *  <p>The format string is interpreted as specified by the
 *  ICU Date/Time Format Syntax.
 *  </p>
 *  <url
 * url="https://unicode-org.github.io/icu/userguide/format_parse/datetime/" />
 */
GS_EXPORT_CLASS
@interface NSDateFormatter : NSFormatter <NSCoding, NSCopying>
{
#if	GS_EXPOSE(NSDateFormatter)
  NSString	*_dateFormat;
  BOOL		_allowsNaturalLanguage;
#endif
#if     GS_NONFRAGILE
#  if	defined(GS_NSDateFormatter_IVARS)
@public
GS_NSDateFormatter_IVARS;
#  endif
#else
  /* Pointer to private additional data used to avoid breaking ABI
   * when we don't have the non-fragile ABI available.
   * Use this mechanism rather than changing the instance variable
   * layout (see Source/GSInternal.h for details).
   */
  @private id _internal GS_UNUSED_IVAR;
#endif
}

/* Initializing an NSDateFormatter */

/**
 *  Initialize with given specifier string format.  See class description for
 *  how to specify a format string.  If flag is YES, string-to-object
 *  conversion will attempt to process strings as natural language dates, such
 *  as "yesterday", or "first Tuesday of next month" if straight format-based
 *  conversion fails.
 */
- (id) initWithDateFormat: (NSString *)format
     allowNaturalLanguage: (BOOL)flag;


/* Determining Attributes */

/**
 *  Returns whether initialized to support natural language formatting.  If
 *  YES, string-to-object conversion will attempt to process strings as
 *  natural language dates, such as "yesterday", or "first Tuesday of next
 *  month" if straight format-based conversion fails.
 */
- (BOOL) allowsNaturalLanguage;

/**
 *  Returns format string initialized with, specifying how dates are formatted,
 *  for object-to-string conversion, and how they are parsed, for
 *  string-to-object conversion.  For example, <code>@"%b %d, %Y"</code>
 *  specifies strings similar to "June 18, 1991".
 */
- (NSString *) dateFormat;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_4, GS_API_LATEST)
+ (NSDateFormatterBehavior) defaultFormatterBehavior;
+ (void) setDefaultFormatterBehavior: (NSDateFormatterBehavior) behavior;

- (NSDateFormatterBehavior) formatterBehavior;
- (void) setFormatterBehavior: (NSDateFormatterBehavior) behavior;
- (BOOL) generatesCalendarDates;
- (void) setGeneratesCalendarDates: (BOOL) flag;
- (BOOL) isLenient;
- (void) setLenient: (BOOL) flag;

- (NSDate *) dateFromString: (NSString *) string;
- (NSString *) stringFromDate: (NSDate *) date;
- (BOOL) getObjectValue: (out id *) obj
              forString: (NSString *) string
                  range: (inout NSRange *) range
                  error: (out NSError **) error;

- (void) setDateFormat: (NSString *) string;
- (NSDateFormatterStyle) dateStyle;
- (void) setDateStyle: (NSDateFormatterStyle) style;
- (NSDateFormatterStyle) timeStyle;
- (void) setTimeStyle: (NSDateFormatterStyle) style;

- (NSCalendar *) calendar;
- (void) setCalendar: (NSCalendar *) calendar;
- (NSDate *) defaultDate;
- (void) setDefaultDate: (NSDate *) date;
- (NSLocale *) locale;
- (void) setLocale: (NSLocale *) locale;
- (NSTimeZone *) timeZone;
- (void) setTimeZone: (NSTimeZone *) tz;
- (NSDate *) twoDigitStartDate;
- (void) setTwoDigitStartDate: (NSDate *) date;

- (NSString *) AMSymbol;
- (void) setAMSymbol: (NSString *) string;
- (NSString *) PMSymbol;
- (void) setPMSymbol: (NSString *) string;

- (NSArray *) weekdaySymbols;
- (void) setWeekdaySymbols: (NSArray *) array;
- (NSArray *) shortWeekdaySymbols;
- (void) setShortWeekdaySymbols: (NSArray *) array;

- (NSArray *) monthSymbols;
- (void) setMonthSymbols: (NSArray *) array;
- (NSArray *) shortMonthSymbols;
- (void) setShortMonthSymbols: (NSArray *) array;

- (NSArray *) eraSymbols;
- (void) setEraSymbols: (NSArray *) array;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
- (NSDate *) gregorianStartDate;
- (void) setGregorianStartDate: (NSDate *) date;

- (NSArray *) longEraSymbols;
- (void) setLongEraSymbols: (NSArray *) array;

- (NSArray *) quarterSymbols;
- (void) setQuarterSymbols: (NSArray *) array;
- (NSArray *) shortQuarterSymbols;
- (void) setShortQuarterSymbols: (NSArray *) array;
- (NSArray *) standaloneQuarterSymbols;
- (void) setStandaloneQuarterSymbols: (NSArray *) array;
- (NSArray *) shortStandaloneQuarterSymbols;
- (void) setShortStandaloneQuarterSymbols: (NSArray *) array;

- (NSArray *) shortStandaloneMonthSymbols;
- (void) setShortStandaloneMonthSymbols: (NSArray *) array;
- (NSArray *) standaloneMonthSymbols;
- (void) setStandaloneMonthSymbols: (NSArray *) array;
- (NSArray *) veryShortMonthSymbols;
- (void) setVeryShortMonthSymbols: (NSArray *) array;
- (NSArray *) veryShortStandaloneMonthSymbols;
- (void) setVeryShortStandaloneMonthSymbols: (NSArray *) array;

- (NSArray *) shortStandaloneWeekdaySymbols;
- (void) setShortStandaloneWeekdaySymbols: (NSArray *) array;
- (NSArray *) standaloneWeekdaySymbols;
- (void) setStandaloneWeekdaySymbols: (NSArray *) array;
- (NSArray *) veryShortWeekdaySymbols;
- (void) setVeryShortWeekdaySymbols: (NSArray *) array;
- (NSArray *) veryShortStandaloneWeekdaySymbols;
- (void) setVeryShortStandaloneWeekdaySymbols: (NSArray *) array;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
+ (NSString *) localizedStringFromDate: (NSDate *) date
                             dateStyle: (NSDateFormatterStyle) dateStyle
                             timeStyle: (NSDateFormatterStyle) timeStyle;
+ (NSString *) dateFormatFromTemplate: (NSString *) aTemplate
                              options: (NSUInteger) opts
                               locale: (NSLocale *) locale;

- (BOOL) doesRelativeDateFormatting;
- (void) setDoesRelativeDateFormatting: (BOOL) flag;
#endif
@end

#endif

#if	defined(__cplusplus)
}
#endif

#endif /* _NSDateFormatter_h_GNUSTEP_BASE_INCLUDE */

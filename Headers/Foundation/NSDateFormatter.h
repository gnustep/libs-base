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
   Library General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/

#ifndef __NSDateFormatter_h_GNUSTEP_BASE_INCLUDE
#define __NSDateFormatter_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)

#import	<Foundation/NSFormatter.h>

#if	defined(__cplusplus)
extern "C" {
#endif

/**
 *  <p>Class for generating text representations of [NSDate]s and
 *  [NSCalendarDate]s, and for converting strings into instances of these
 *  objects.  Note that [NSDate] and [NSCalendarDate] do contain some
 *  string conversion methods, but using this class provides more control
 *  over conversion.</p>
 *  <p>See the [NSFormatter] documentation for description of the basic methods
 *  for formatting and parsing that are available.</p>
 *  <p>The basic format of a format string uses "%" codes to represent
 *  components of the date.  Thus, for example, <code>@"%b %d, %Y"</code>
 *  specifies strings similar to "June 18, 1991".  The full list of codes is
 *  as follows:</p>
 *  <deflist>
 *  <term>%%</term>
 *  <desc>a '%' character</desc>
 *  <term>%a</term>
 *  <desc>abbreviated weekday name</desc>
 *  <term>%A</term>
 *  <desc>full weekday name</desc>
 *  <term>%b</term>
 *  <desc>abbreviated month name</desc>
 *  <term>%B</term>
 *  <desc>full month name</desc>
 *  <term>%c</term>
 *  <desc>shorthand for "%X %x", the locale format for date and time</desc>
 *  <term>%d</term>
 *  <desc>day of the month as a decimal number (01-31)</desc>
 *  <term>%e</term>
 *  <desc>same as %d but does not print the leading 0 for days 1 through 9
 *  (unlike strftime(), does not print a leading space)</desc>
 *  <term>%F</term>
 *  <desc>milliseconds as a decimal number (000-999)</desc>
 *  <term>%H</term>
 *  <desc>hour based on a 24-hour clock as a decimal number (00-23)</desc>
 *  <term>%I</term>
 *  <desc>hour based on a 12-hour clock as a decimal number (01-12)</desc>
 *  <term>%j</term>
 *  <desc>day of the year as a decimal number (001-366)</desc>
 *  <term>%m</term>
 *  <desc>month as a decimal number (01-12)</desc>
 *  <term>%M</term>
 *  <desc>minute as a decimal number (00-59)</desc>
 *  <term>%p</term>
 *  <desc>AM/PM designation for the locale</desc>
 *  <term>%S</term>
 *  <desc>second as a decimal number (00-59)</desc>
 *  <term>%w</term>
 *  <desc>weekday as a decimal number (0-6), where Sunday is 0</desc>
 *  <term>%x</term>
 *  <desc>date using the date representation for the locale, including the
 *  time zone (produces different results from strftime())</desc>
 *  <term>%X</term>
 *  <desc>time using the time representation for the locale (produces
 *  different results from strftime())</desc>
 *  <term>%y</term>
 *  <desc>year without century (00-99)</desc>
 *  <term>%Y</term>
 *  <desc>year with century (such as 1990)</desc>
 *  <term>%Z</term>
 *  <desc>time zone name (such as Pacific Daylight Time; produces different
 *  results from strftime())</desc>
 *  <term>%z</term>
 *  <desc>time zone offset in hours and minutes from GMT (HHMM)</desc>
 * </deflist>
 */
@interface NSDateFormatter : NSFormatter <NSCoding, NSCopying>
{
#if	GS_EXPOSE(NSDateFormatter)
  NSString	*_dateFormat;
  BOOL		_allowsNaturalLanguage;
  NSLocale  *locale;
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
- (NSLocale*)locale;
- (void)setLocale: (NSLocale*)aLocale;
@end

extern NSString *const NSDateFormatterLongStyle;
extern NSString *const NSDateFormatterShortStyle;
extern NSString *const NSDateFormatterNoStyle;

#endif

#if	defined(__cplusplus)
}
#endif

#endif /* _NSDateFormatter_h_GNUSTEP_BASE_INCLUDE */

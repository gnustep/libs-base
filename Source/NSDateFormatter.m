/* Implementation of NSDateFormatter class
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: December 1998

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
   */

#include <config.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSFormatter.h>
#include <Foundation/NSDateFormatter.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>

@implementation NSDateFormatter

- (BOOL) allowsNaturalLanguage
{
  return allowsNaturalLanguage;
}

- (NSAttributedString*) attributedStringForObjectValue: (id)anObject
				 withDefaultAttributes: (NSDictionary*)attr
{
  return nil;
}

- (id) copyWithZone: (NSZone*)zone
{
  NSDateFormatter	*other = (id)NSCopyObject(self, 0, zone);

  RETAIN(other->dateFormat);
  return other;
}

- (NSString*) dateFormat
{
  return dateFormat;
}

- (void) dealloc
{
  RELEASE(dateFormat);
  [super dealloc];
}

- (NSString*) editingStringForObjectValue: (id)anObject
{
  return [self stringForObjectValue: anObject];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeValuesOfObjCTypes: "@C", &dateFormat, &allowsNaturalLanguage];
}

- (BOOL) getObjectValue: (id*)anObject
	      forString: (NSString*)string
       errorDescription: (NSString**)error
{
  NSCalendarDate	*d;

  d = [NSCalendarDate dateWithString: string calendarFormat: dateFormat];
  if (d == nil)
    {
      if (allowsNaturalLanguage)
	{
	  d = [NSCalendarDate dateWithNaturalLanguageString: string];
	}
      if (d == nil)
	{
	  *error = @"Couldn't convert to date";
	  return NO;
	}
    }
  *anObject = d;
  return YES;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [aCoder decodeValuesOfObjCTypes: "@C", &dateFormat, &allowsNaturalLanguage];
  return self;
}

- (id) initWithDateFormat: (NSString *)format
     allowNaturalLanguage: (BOOL)flag
{
  dateFormat = [format copy];
  allowsNaturalLanguage = flag;
  return self;
}

- (BOOL) isPartialStringValid: (NSString*)partialString
	     newEditingString: (NSString**)newString
	     errorDescription: (NSString**)error
{
  *newString = nil;
  *error = nil;
  return YES;
}

- (NSString*) stringForObjectValue: (id)anObject
{
  if ([anObject isKindOfClass: [NSDate class]] == NO)
    {
      return nil;
    }
  return [anObject descriptionWithCalendarFormat: dateFormat
					timeZone: [NSTimeZone defaultTimeZone]
					  locale: nil];
}
@end


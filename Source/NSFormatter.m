/* Implementation of NSFormatter class
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: October 1998

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
#include <Foundation/NSFormatter.h>

@implementation NSFormatter

- (NSAttributedString*) attributedStringForObjectValue: (id)anObject
				 withDefaultAttributes: (NSDictionary*)attr
{
  return nil;
}

- (id) copyWithZone: (NSZone*)zone
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSString*) editingStringForObjectValue: (id)anObject
{
  return [self stringForObjectValue: anObject];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
}

- (BOOL) getObjectValue: (id*)anObject
	      forString: (NSString*)string
       errorDescription: (NSString**)error
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
  return nil;
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
  [self subclassResponsibility: _cmd];
  return nil;
}
@end


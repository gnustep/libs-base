/* NSConcreteValue - Interface for Concrete NSValue classes
    
   Copyright (C) 1993,1994,1995,1999 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Mar 1995

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

#ifndef __NSConcreteValue_OBJECT_INCLUDE
#define __NSConcreteValue_OBJECT_INCLUDE

#include <Foundation/NSValue.h>

@interface NSConcreteValue : NSValue
{
  void *data;
  char *objctype;
}
@end

@interface NSNonretainedObjectValue : NSValue
{
  id data;
}
@end

@interface NSPointValue : NSValue
{
  NSPoint data;
}
@end

@interface NSPointerValue : NSValue
{
  void *data;
}
@end

@interface NSRectValue : NSValue
{
  NSRect data;
}
@end

@interface NSSizeValue : NSValue
{
  NSSize data;
}
@end

#endif

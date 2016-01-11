/** Implementation of NSCopyObject() for GNUStep
   Copyright (C) 1994, 1995 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: August 1994

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

   <title>NSCopyObject class reference</title>
   $Date$ $Revision$
   */

#import "common.h"

#ifdef __GNUSTEP_RUNTIME__
#include <objc/capabilities.h>
#if defined(OBJC_CAP_ARC)
//#define USE_USE_OBJC_CAP_ARC
#endif
#endif

NSObject *NSCopyObject(NSObject *anObject, NSUInteger extraBytes, NSZone *zone)
{
  Class	c = object_getClass(anObject);
#if defined(USE_USE_OBJC_CAP_ARC)
  id copy = object_copy(anObject, class_getInstanceSize(c) + extraBytes);
#else
  id copy = NSAllocateObject(c, extraBytes, zone);
  memcpy(copy, anObject, class_getInstanceSize(c) + extraBytes);
#endif
  
  return copy;
}

NSObject *NSCopyObject_TP(NSObject *anObject, NSUInteger extraBytes, NSZone *zone)
{
  Class	c = object_getClass(anObject);
  id copy = NSAllocateObject(c, extraBytes, zone);
  memcpy(((char*)copy + sizeof(id)), ((char*)anObject + sizeof(id)), class_getInstanceSize(c) - sizeof(id));
  return copy;
}

/* Interface to ObjC runtime for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
   This file is part of the Gnustep Base Library.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#ifndef __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE
#define __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE

#include <objc/objc.h>

@class NSString;

extern NSString *NSStringFromSelector(SEL aSelector);
extern SEL NSSelectorFromString(NSString *aSelectorName);
extern Class NSClassFromString(NSString *aClassName);
extern NSString *NSStringFromClass(Class aClass);

#ifndef YES
#define YES		1
#endif YES
#ifndef NO
#define NO		0
#endif NO
#ifndef nil
#define nil		0
#endif nil

#endif /* __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE */

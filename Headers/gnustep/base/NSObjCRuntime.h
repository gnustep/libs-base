/* Interface to ObjC runtime for GNUStep
   Copyright (C) 1995, 1997 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#ifndef __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE
#define __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE

#include <objc/objc.h>
#include <Foundation/NSString.h>

extern NSString *NSStringFromSelector(SEL aSelector);
extern SEL NSSelectorFromString(NSString *aSelectorName);
extern Class NSClassFromString(NSString *aClassName);
extern NSString *NSStringFromClass(Class aClass);
extern const char *NSGetSizeAndAlignment(const char *typePtr, unsigned int *sizep, unsigned int *alignp);

/* Logging */
/* OpenStep spec states that log messages go to stderr, but just in case
   someone wants them to go somewhere else, they can implement a function
   like this */
typedef void NSLog_printf_handler (NSString* message);
extern NSLog_printf_handler *_NSLog_printf_handler;

extern void NSLog (NSString* format, ...);
extern void NSLogv (NSString* format, va_list args);

#ifndef YES
#define YES		1
#endif YES
#ifndef NO
#define NO		0
#endif NO
#ifndef nil
#define nil		0
#endif nil

#ifndef	NO_GNUSTEP
extern BOOL GSGetInstanceVariable(id obj, NSString *name, void* data);
extern BOOL GSSetInstanceVariable(id obj, NSString *name, void* data);
#endif

#define FOUNDATION_EXPORT
#define FOUNDATION_STATIC_INLINE static inline

#endif /* __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE */

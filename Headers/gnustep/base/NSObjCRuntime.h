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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

#ifndef __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE
#define __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE

#include <objc/objc.h>
#include <stdarg.h>

#if BUILD_libgnustep-base_DLL
#  define GS_EXPORT __declspec(dllexport)
#elif libgnustep-base_ISDLL
#  define GS_EXPORT extern __declspec(dllimport)
#else
#  define GS_EXPORT extern
#endif
#define GS_IMPORT extern

@class	NSString;

GS_EXPORT NSString *NSStringFromSelector(SEL aSelector);
GS_EXPORT SEL NSSelectorFromString(NSString *aSelectorName);
GS_EXPORT Class NSClassFromString(NSString *aClassName);
GS_EXPORT NSString *NSStringFromClass(Class aClass);
GS_EXPORT const char *NSGetSizeAndAlignment(const char *typePtr, unsigned int *sizep, unsigned int *alignp);

/* Logging */
/* OpenStep spec states that log messages go to stderr, but just in case
   someone wants them to go somewhere else, they can implement a function
   like this */
typedef void NSLog_printf_handler (NSString* message);
GS_EXPORT NSLog_printf_handler *_NSLog_printf_handler;

GS_EXPORT void NSLog (NSString* format, ...);
GS_EXPORT void NSLogv (NSString* format, va_list args);

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
GS_EXPORT BOOL GSGetInstanceVariable(id obj, NSString *name, void* data);
GS_EXPORT BOOL GSSetInstanceVariable(id obj, NSString *name, const void* data);
#endif

#define FOUNDATION_EXPORT
#define FOUNDATION_STATIC_INLINE static inline

#endif /* __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE */

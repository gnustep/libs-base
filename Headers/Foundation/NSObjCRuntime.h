/** Interface to ObjC runtime for GNUStep
   Copyright (C) 1995, 1997, 2000 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
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

    AutogsdocSource: NSObjCRuntime.m
    AutogsdocSource: NSLog.m

   */ 

#ifndef __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE
#define __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>
#import	<GNUstepBase/preface.h>
#import	<GNUstepBase/GSConfig.h>

/* These typedefs must be in place before GSObjCRuntime.h is imported.
 */
typedef	intptr_t	NSInteger;
typedef	uintptr_t	NSUInteger;
#if	GS_SIZEOF_VOIDP == 8
typedef	double		CGFloat;
#else
typedef	float		CGFloat;
#endif

#define NSINTEGER_DEFINED 1

#import	<GNUstepBase/GSObjCRuntime.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if OS_API_VERSION(100500,GS_API_LATEST) 
GS_EXPORT NSString	*NSStringFromProtocol(Protocol *aProtocol);
GS_EXPORT Protocol	*NSProtocolFromString(NSString *aProtocolName);
#endif
GS_EXPORT SEL		NSSelectorFromString(NSString *aSelectorName);
GS_EXPORT NSString	*NSStringFromSelector(SEL aSelector);
GS_EXPORT SEL		NSSelectorFromString(NSString *aSelectorName);
GS_EXPORT Class		NSClassFromString(NSString *aClassName);
GS_EXPORT NSString	*NSStringFromClass(Class aClass);
GS_EXPORT const char	*NSGetSizeAndAlignment(const char *typePtr,
  unsigned int *sizep, unsigned int *alignp);

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)
/* Logging */
/**
 *  OpenStep spec states that log messages go to stderr, but just in case
 *  someone wants them to go somewhere else, they can implement a function
 *  like this and assign a pointer to it to _NSLog_printf_handler.
 */
typedef void NSLog_printf_handler (NSString* message);
GS_EXPORT NSLog_printf_handler	*_NSLog_printf_handler;
GS_EXPORT int	_NSLogDescriptor;
@class NSRecursiveLock;
GS_EXPORT NSRecursiveLock	*GSLogLock(void);
#endif

GS_EXPORT void			NSLog (NSString *format, ...);
GS_EXPORT void			NSLogv (NSString *format, va_list args);

#ifndef YES
#define YES		1
#endif
#ifndef NO
#define NO		0
#endif
#ifndef nil
#define nil		0
#endif

#if	defined(__cplusplus)
}
#endif

#endif /* __NSObjCRuntime_h_GNUSTEP_BASE_INCLUDE */

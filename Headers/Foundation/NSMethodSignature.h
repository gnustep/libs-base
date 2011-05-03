/* Interface for NSMethodSignature for GNUStep
   Copyright (C) 1995, 1998 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   Rewritten:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1998
   
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */ 

#ifndef __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE
#define __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if OS_API_VERSION(GS_API_NONE, GS_API_MACOSX)
/**
 *	<p>Info about layout of arguments.
 *	Extended from the original OpenStep version to let us know if the
 *	arg is passed in registers or on the stack.</p>
 *
 *	<p>NB. This no longer exists in Rhapsody/MacOS.</p>
 <example>
typedef struct	{
  int		offset;
  unsigned	size;
  const char	*type;
  unsigned	align;  // extension, available only in GNUSTEP
  unsigned	qual;   // extension, available only in GNUSTEP
  BOOL		isReg;  // extension, available only in GNUSTEP
} NSArgumentInfo;
 </example>
 *      <p>NB. The offset and register information may not always be reliable.
 *      In the past it was dependent on locally maintained platform dependent 
 *      information.  In the future it may depend on layout information
 *      supplied by the compiler.</p>
 */
typedef struct	{
  int		offset;
  unsigned	size;
  const char	*type;
#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)
  unsigned	align;
  unsigned	qual;
  BOOL		isReg;
#else
  unsigned	_reserved1;
  unsigned	_reserved2;
  BOOL		_reserved3;
#endif
} NSArgumentInfo;
#endif

/**
 * <p>Class encapsulating type information for method arguments and return
 * value.  It is used as a component of [NSInvocation] to implement message
 * forwarding, such as within the distributed objects framework.  Instances
 * can be obtained from the [NSObject] method
 * [NSObject-methodSignatureForSelector:].</p>
 *
 * <p>Basically, types are represented as Objective-C <code>@encode(...)</code>
 * compatible strings, together with size information.  The arguments are
 * numbered starting from 0, including the implicit arguments
 * <code><em>self</em></code> (type <code>id</code>, at position 0) and
 * <code><em>_cmd</em></code> (type <code>SEL</code>, at position 1).</p>
 */
@interface NSMethodSignature : NSObject
{
  const char		*_methodTypes;
  unsigned		_argFrameLength;
  unsigned		_numArgs;
#if OS_API_VERSION(GS_API_NONE, GS_API_MACOSX)
  NSArgumentInfo	*_info;
#else
  void			*_info;
#endif
}

/**
 * Build a method signature directly from string description of return type and
 * argument types, using the Objective-C <code>@encode(...)</code> type codes.
 */
+ (NSMethodSignature*) signatureWithObjCTypes: (const char*)t;

#if OS_API_VERSION(GS_API_OPENSTEP, GS_API_MACOSX)
/**
 * Returns full information on given argument.  Indices start at 0.  Provide
 * -1 to get info on return value.
 */
- (NSArgumentInfo) argumentInfoAtIndex: (unsigned)index;
#endif

/**
 * Number of bytes that the full set of arguments occupies on the stack, which
 * is platform(hardware)-dependent.
 */
- (unsigned) frameLength;

/**
 * Returns Objective-C <code>@encode(...)</code> compatible string.  Arguments
 * are numbered starting from 0, including the implicit arguments
 * <code><em>self</em></code> (type <code>id</code>, at position 0) and
 * <code><em>_cmd</em></code> (type <code>SEL</code>, at position 1).
 */
- (const char*) getArgumentTypeAtIndex: (unsigned)index;

/**
 * Pertains to distributed objects; method is asynchronous when invoked and
 * return should not be waited for.
 */
- (BOOL) isOneway;

/**
 * Number of bytes that the return value occupies on the stack, which is
 * platform(hardware)-dependent.
 */
- (unsigned) methodReturnLength;

/**
 * Returns Objective-C <code>@encode(...)</code> compatible string.  Arguments
 * are numbered starting from 0, including the implicit arguments
 * <code><em>self</em></code> (type <code>id</code>, at position 0) and
 * <code><em>_cmd</em></code> (type <code>SEL</code>, at position 1).
 */
- (const char*) methodReturnType;

/**
 * Returns number of arguments to method, including the implicit
 * <code><em>self</em></code> and <code><em>_cmd</em></code>.
 */
- (unsigned) numberOfArguments;

@end

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)
/**
 * Declares a convenience method for getting the entire array of raw type and
 * size information.
 */
@interface NSMethodSignature(GNUstep)
/**
 * Convenience method for getting the entire array of raw type and size
 * information.
 */
- (NSArgumentInfo*) methodInfo;

/**
 * Returns a string containing all Objective-C
 * <code>@encode(...)</code> compatible type information.
 */
- (const char*) methodType;
@end
#endif

#if	defined(__cplusplus)
}
#endif

#endif /* __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE */

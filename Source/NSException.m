/** NSException - Object encapsulation of a general exception handler
   Copyright (C) 1993, 1994, 1996, 1997, 1999 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSException class reference</title>
   $Date$ $Revision$
*/

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSDictionary.h>
#include <stdio.h>

/**
 * A generic exception for general purpose usage.
 */
NSString* const NSGenericException
  = @"NSGenericException";

/**
 * An exception for caes where unexpected state is detected within an object
 */
NSString* const NSInternalInconsistencyException
  = @"NSInternalInconsistencyException";

/**
 * An exception used when an invalid argument is passed to a method
 * or function.
 */
NSString* const NSInvalidArgumentException
  = @"NSInvalidArgumentException";

/**
 * An exception used when the system faols to allocate required memory.
 */
NSString* const NSMallocException
  = @"NSMallocException";

/**
 * An exception used when an illegal range is encountered ... usually this
 * is used to provide more information than an invalid argument exception.
 */
NSString* const NSRangeException
 = @"NSRangeException";

/**
 * An exception when character set conversion fails.
 */
NSString* const NSCharacterConversionException
  = @"NSCharacterConversionException";

/**
 * An exception used when some form of parsing fails.
 */
NSString* const NSParseErrorException
  = @"NSParseErrorException";

#include "GSPrivate.h"

static void
_preventRecursion (NSException *exception)
{
  fprintf(stderr, "recursion encountered handling uncaught exception\n");
  fflush(stderr);	/* NEEDED UNDER MINGW */
}

static void
_NSFoundationUncaughtExceptionHandler (NSException *exception)
{
  BOOL			a;
  extern const char*	GSArgZero(void);

  _NSUncaughtExceptionHandler = _preventRecursion;
#if 1
  fprintf(stderr, "%s: Uncaught exception %s, reason: %s\n", GSArgZero(),
    [[exception name] lossyCString], [[exception reason] lossyCString]);
  fflush(stderr);	/* NEEDED UNDER MINGW */
#else
  NSLog("Uncaught exception %@, reason: %@",
    [exception name], [exception reason]);
#endif

#ifdef	DEBUG
  a = YES;		// abort() by default.
#else
  a = NO;		// exit() by default.
#endif
  a = GSEnvironmentFlag("CRASH_ON_ABORT", a);
  if (a == YES)
    {
      abort();
    }
  else
    {
      exit(1);
    }
}

/**
   <p>
   The NSException class helps manage errors in a program. It provides
   a mechanism for lower-level methods to provide information about
   problems to higher-level methods, which more often than not, have a
   better ability to decide what to do about the problems.
   </p>
   <p>
   Exceptions are typically handled by enclosing a sensitive section
   of code inside the macros NS_DURING and NS_HANDLER, and then
   handling any problems after this, up to the NS_ENDHANDLER macro:
   </p>
   <example>
   NS_DURING
    code that might cause an exception
   NS_HANDLER
    code that deals with the exception. If this code cannot deal with
    it, you can re-raise the exception like this
    [localException raise]
    so the next higher level of code can handle it
   NS_ENDHANDLER
   </example>
   <p>
   The local variable localException is the name of the exception
   object you can use in the NS_HANDLER section.
   The easiest way to cause an exeption is using the +raise:format:
   method.
   </p>
*/
@implementation NSException

/**
   Create an an exception object with a name, reason and a dictionary
   userInfo which can be used to provide additional information or
   access to objects needed to handle the exception. After the
   exception is created you must -raise it.
*/
+ (NSException*) exceptionWithName: (NSString*)name
			    reason: (NSString*)reason
			  userInfo: (NSDictionary*)userInfo
{
  return AUTORELEASE([[self alloc] initWithName: name reason: reason
				   userInfo: userInfo]);
}

/**
   Creates an exception with a name and a reason using the
   format string and any additional arguments. The exception is then
   raised.
 */
+ (void) raise: (NSString*)name
	format: (NSString*)format,...
{
  va_list args;

  va_start(args, format);
  [self raise: name format: format arguments: args];
  // This probably doesn't matter, but va_end won't get called
  va_end(args);
}

/**
   Creates an exception with a name and a reason string using the
   format string and additional arguments specified as a variable
   argument list argList. The exception is then raised.
 */
+ (void) raise: (NSString*)name
	format: (NSString*)format
     arguments: (va_list)argList
{
  NSString	*reason;
  NSException	*except;

  reason = [NSString stringWithFormat: format arguments: argList];
  except = [self exceptionWithName: name reason: reason userInfo: nil];
  [except raise];
}

/**
   <init/>Initializes a newly allocated NSException object with a
   name, reason and a dictionary userInfo.
*/
- (id) initWithName: (NSString*)name
	     reason: (NSString*)reason
	   userInfo: (NSDictionary*)userInfo
{
  ASSIGN(_e_name, name);
  ASSIGN(_e_reason, reason);
  ASSIGN(_e_info, userInfo);
  return self;
}

- (void) dealloc
{
  DESTROY(_e_name);
  DESTROY(_e_reason);
  DESTROY(_e_info);
  [super dealloc];
}

/**
   Raises the exception. All code following the raise will not be
   executed and program control will be transfered to the closest
   calling method which encapsulates the exception code in an
   NS_DURING macro, or to the uncaught exception handler if there is no
   other handling code.
*/
- (void) raise
{
  NSThread	*thread;
  NSHandler	*handler;

  if (_NSUncaughtExceptionHandler == NULL)
    {
      _NSUncaughtExceptionHandler = _NSFoundationUncaughtExceptionHandler;
    }

  thread = GSCurrentThread();
  handler = thread->_exception_handler;
  if (handler == NULL)
    {
      _NSUncaughtExceptionHandler(self);
      return;
    }

  thread->_exception_handler = handler->next;
  handler->exception = self;
  longjmp(handler->jumpState, 1);
}

/** Returns the name of the exception */
- (NSString*) name
{
  if (_e_name != nil)
    {
      return _e_name;
    }
  else
    {
      return NSStringFromClass([self class]);
    }
}

/** Returns the exception reason */
- (NSString*) reason
{
  if (_e_reason != nil)
    {
      return _e_reason;
    }
  else
    {
      return @"unspecified reason";
    }
}

/** Returns the exception userInfo dictionary */
- (NSDictionary*) userInfo
{
  return _e_info;
}

- (Class) classForPortCoder
{
  return [self class];
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  return self;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeValueOfObjCType: @encode(id) at: &_e_name];
  [aCoder encodeValueOfObjCType: @encode(id) at: &_e_reason];
  [aCoder encodeValueOfObjCType: @encode(id) at: &_e_info];
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  [aDecoder decodeValueOfObjCType: @encode(id) at: &_e_name];
  [aDecoder decodeValueOfObjCType: @encode(id) at: &_e_reason];
  [aDecoder decodeValueOfObjCType: @encode(id) at: &_e_info];
  return self;
}

- (id) deepen
{
  _e_name = [_e_name copyWithZone: [self zone]];
  _e_reason = [_e_reason copyWithZone: [self zone]];
  _e_info = [_e_info copyWithZone: [self zone]];
  return self;
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    return RETAIN(self);
  else
    return [(NSException*)NSCopyObject(self, 0, zone) deepen];
}

- (NSString*) description
{
  if (_e_info)
    return [NSString stringWithFormat: @"%@ NAME:%@ REASON:%@ INFO:%@",
	[super description], _e_name, _e_reason, _e_info];
  else
    return [NSString stringWithFormat: @"%@ NAME:%@ REASON:%@",
	[super description], _e_name, _e_reason];
}

@end


void
_NSAddHandler (NSHandler* handler)
{
  NSThread *thread;

  thread = GSCurrentThread();
  handler->next = thread->_exception_handler;
  thread->_exception_handler = handler;
}

void
_NSRemoveHandler (NSHandler* handler)
{
  NSThread *thread;

  thread = GSCurrentThread();
  thread->_exception_handler = thread->_exception_handler->next;
}

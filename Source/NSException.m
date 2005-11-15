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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.

   $Date$ $Revision$
*/

#include "config.h"
#include "GNUstepBase/preface.h"
#include "Foundation/NSException.h"
#include "Foundation/NSString.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSCoder.h"
#include "Foundation/NSThread.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSProcessInfo.h"
#include <stdio.h>

/**
 * A generic exception for general purpose usage.
 */
NSString* const NSGenericException
  = @"NSGenericException";

/**
 * An exception for cases where unexpected state is detected within an object.
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
 * An exception used when the system fails to allocate required memory.
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

static void _terminate()
{
  BOOL			shouldAbort;

#ifdef	DEBUG
  shouldAbort = YES;		// abort() by default.
#else
  shouldAbort = NO;		// exit() by default.
#endif
  shouldAbort = [[[[NSProcessInfo processInfo] environment]
    objectForKey: @"CRASH_ON_ABORT"] boolValue];
  if (shouldAbort == YES)
    {
      abort();
    }
  else
    {
      exit(1);
    }
}

static void
_NSFoundationUncaughtExceptionHandler (NSException *exception)
{
  extern const char*	GSArgZero(void);

  fprintf(stderr, "%s: Uncaught exception %s, reason: %s\n", GSArgZero(),
    [[exception name] lossyCString], [[exception reason] lossyCString]);
  fflush(stderr);	/* NEEDED UNDER MINGW */

  _terminate();
}

/**
   <p>
   The <code>NSException</code> class helps manage errors in a program. It
   provides a mechanism for lower-level methods to provide information about
   problems to higher-level methods, which more often than not, have a
   better ability to decide what to do about the problems.
   </p>
   <p>
   Exceptions are typically handled by enclosing a sensitive section
   of code inside the macros <code>NS_DURING</code> and <code>NS_HANDLER</code>,
   and then handling any problems after this, up to the
   <code>NS_ENDHANDLER</code> macro:
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
   The local variable <code>localException</code> is the name of the exception
   object you can use in the <code>NS_HANDLER</code> section.
   The easiest way to cause an exception is using the +raise:format:,...
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
   NS_DURING macro.<br />
   If the exception was not caught in a macro, the currently set
   uncaught exception handler is called to perform final logging
   and handle program termination.<br />
   If the uncaught exception handler fails to terminate the program,
   then the default builtin uncaught exception handler will do so.<br />
   NB. all other exception raising methods call this one, so if you
   want to set a breakpoint when debugging, set it in this method.
*/
- (void) raise
{
  NSThread	*thread;
  NSHandler	*handler;

  thread = GSCurrentThread();
  handler = thread->_exception_handler;
  if (handler == NULL)
    {
      static	BOOL	recursion = NO;

      /*
       * Set a flag to prevent recursive uncaught exceptions.
       */
      if (recursion == NO)
	{
	  recursion = YES;
	}
      else
	{
	  fprintf(stderr,
	    "recursion encountered handling uncaught exception\n");
	  fflush(stderr);	/* NEEDED UNDER MINGW */
	  _terminate();
	}

      /*
       * Call the uncaught exception handler (if there is one).
       */
      if (_NSUncaughtExceptionHandler != NULL)
	{
	  (*_NSUncaughtExceptionHandler)(self);
	}

      /*
       * The uncaught exception handler which is set has not
       * exited, so we call the builtin handler, (undocumented
       * behavior of MacOS-X).
       * The standard handler is guaranteed to exit/abort.
       */
      _NSFoundationUncaughtExceptionHandler(self);
    }

  thread->_exception_handler = handler->next;
  handler->exception = self;
  longjmp(handler->jumpState, 1);
}

/** Returns the name of the exception. */
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

/** Returns the exception reason. */
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

/** Returns the exception userInfo dictionary. */
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
#if defined(__WIN32__) && defined(DEBUG)
  if (thread->_exception_handler
    && IsBadReadPtr(thread->_exception_handler, sizeof(NSHandler)))
    {
      fprintf(stderr, "ERROR: Current exception handler is bogus.\n");
    }
#endif  
  handler->next = thread->_exception_handler;
  thread->_exception_handler = handler;
}

void
_NSRemoveHandler (NSHandler* handler)
{
  NSThread *thread;

  thread = GSCurrentThread();
#if defined(DEBUG)  
  if (thread->_exception_handler != handler)
    {
      fprintf(stderr, "ERROR: Removing exception handler that is not on top "
	"of the stack. (You probably called return in an NS_DURING block.)\n");
    }
#if defined(__WIN32__)
  if (IsBadReadPtr(handler, sizeof(NSHandler)))
    {
      fprintf(stderr, "ERROR: Could not remove exception handler, "
	"handler is bad pointer.\n");
      thread->_exception_handler = 0;
      return;
    }
  if (handler->next && IsBadReadPtr(handler->next, sizeof(NSHandler)))
    {
      fprintf(stderr, "ERROR: Could not restore exception handler, "
	"handler->next is bad pointer.\n");
      thread->_exception_handler = 0;
      return;
    }
#endif
#endif
  thread->_exception_handler = handler->next;
}

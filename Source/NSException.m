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
const NSString* const NSGenericException
  = @"NSGenericException";

/**
 * An exception for caes where unexpected state is detected within an object
 */
const NSString* const NSInternalInconsistencyException
  = @"NSInternalInconsistencyException";

/**
 * An exception used when an invalid argument is passed to a method
 * or function.
 */
const NSString* const NSInvalidArgumentException
  = @"NSInvalidArgumentException";

/**
 * An exception used when the system faols to allocate required memory.
 */
const NSString* const NSMallocException
  = @"NSMallocException";

/**
 * An exception used when an illegal range is encountered ... usually this
 * is used to provide more information than an invalid argument exception.
 */
const NSString* const NSRangeException
 = @"NSRangeException";

/**
 * An exception when character set conversion fails.
 */
const NSString* const NSCharacterConversionException
  = @"NSCharacterConversionException";

/**
 * An exception used when some form of parsing fails.
 */
const NSString* const NSParseErrorException
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
  extern const char*	GSArgZero();

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

@implementation NSException

+ (NSException*) exceptionWithName: (NSString*)name
			    reason: (NSString*)reason
			  userInfo: (NSDictionary*)userInfo
{
  return AUTORELEASE([[self alloc] initWithName: name reason: reason
				   userInfo: userInfo]);
}

+ (void) raise: (NSString*)name
	format: (NSString*)format,...
{
  va_list args;

  va_start(args, format);
  [self raise: name format: format arguments: args];
  // FIXME: This probably doesn't matter, but va_end won't get called
  va_end(args);
}

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

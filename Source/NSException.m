/* NSException - Object encapsulation of a general exception handler
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSDictionary.h>

static volatile void
_NSFoundationUncaughtExceptionHandler(NSException *exception)
{
  fprintf(stderr, "Uncaught exception %s, reason: %s\n",
    	[[exception name] cString], [[exception reason] cString]);
/* FIXME: need to implement this:
  NSLogError("Uncaught exception %@, reason: %@",
    	[exception name], [exception reason]);
*/
  abort();
}

@implementation NSException

+ (NSException*) exceptionWithName: (NSString *)name
			    reason: (NSString *)reason
			  userInfo: (NSDictionary *)userInfo
{
  return AUTORELEASE([[self alloc] initWithName: name reason: reason
		      userInfo: userInfo]);
}

+ (volatile void) raise: (NSString *)name
		 format: (NSString *)format,...
{
  va_list args;

  va_start(args, format);
  [self raise: name format: format arguments: args];
  // FIXME: This probably doesn't matter, but va_end won't get called
  va_end(args);
}

+ (volatile void) raise: (NSString *)name
		 format: (NSString *)format
	      arguments: (va_list)argList
{
  NSString	*reason;
  NSException	*except;

  reason = [NSString stringWithFormat: format arguments: argList];
  except = [self exceptionWithName: name reason: reason userInfo: nil];
  [except raise];
}

- (id) initWithName: (NSString *)name
	     reason: (NSString *)reason
	   userInfo: (NSDictionary *)userInfo
{
  ASSIGN(e_name, name);
  ASSIGN(e_reason, reason);
  ASSIGN(e_info, userInfo);
  return self;
}

- (void)dealloc
{
  DESTROY(e_name);
  DESTROY(e_reason);
  DESTROY(e_info);
  [super dealloc];
}

- (volatile void) raise
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

- (NSString *) name
{
  return e_name;
}

- (NSString *) reason
{
  return e_reason;
}

- (NSDictionary *) userInfo
{
  return e_info;
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
  [aCoder encodeValueOfObjCType: @encode(id) at: &e_name];
  [aCoder encodeValueOfObjCType: @encode(id) at: &e_reason];
  [aCoder encodeValueOfObjCType: @encode(id) at: &e_info];
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  [aDecoder decodeValueOfObjCType: @encode(id) at: &e_name];
  [aDecoder decodeValueOfObjCType: @encode(id) at: &e_reason];
  [aDecoder decodeValueOfObjCType: @encode(id) at: &e_info];
  return self;
}

- (id) deepen
{
  e_name = [e_name copyWithZone: [self zone]];
  e_reason = [e_reason copyWithZone: [self zone]];
  e_info = [e_info copyWithZone: [self zone]];
  return self;
}

- (id) copyWithZone: (NSZone *)zone
{
  if (NSShouldRetainWithZone(self, zone))
    return RETAIN(self);
  else
    return [(NSException*)NSCopyObject(self, 0, zone) deepen];
}

- (NSString*) description
{
  if (e_info)
    return [NSString stringWithFormat: @"%@ NAME:%@ REASON:%@ INFO:%@",
	[super description], e_name, e_reason, e_info];
  else
    return [NSString stringWithFormat: @"%@ NAME:%@ REASON:%@",
	[super description], e_name, e_reason];
}

@end


void
_NSAddHandler( NSHandler *handler )
{
  NSThread *thread;

  thread = GSCurrentThread();
  handler->next = thread->_exception_handler;
  thread->_exception_handler = handler;
}

void
_NSRemoveHandler( NSHandler *handler )
{
  NSThread *thread;

  thread = GSCurrentThread();
  thread->_exception_handler = thread->_exception_handler->next;
}

/* NSException - Object encapsulation of a general exception handler
   Copyright (C) 1993, 1994, 1996, 1997 Free Software Foundation, Inc.

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

#include <gnustep/base/preface.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSDictionary.h>

NSString *NSGenericException = @"NSGenericException";
NSString *NSInternalInconsistencyException
	= @"NSInternalInconsistencyException";
NSString *NSInvalidArgumentException = @"NSInvalidArgumentException";
NSString *NSMallocException = @"NSMallocException";
NSString *NSRangeException = @"NSRangeException";

NSUncaughtExceptionHandler *_NSUncaughtExceptionHandler;

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

+ (NSException *)exceptionWithName:(NSString *)name
			    reason:(NSString *)reason
			  userInfo:(NSDictionary *)userInfo 
{
    return [[[self alloc] initWithName:name reason:reason
			userInfo:userInfo] autorelease];
}

+ (volatile void)raise:(NSString *)name
	format:(NSString *)format,...
{
    va_list args;

    va_start(args, format);
    [self raise:name format:format arguments:args];
    // FIXME: This probably doesn't matter, but va_end won't get called
    va_end(args);
}

+ (volatile void)raise:(NSString *)name
	format:(NSString *)format
	arguments:(va_list)argList
{
    NSString *reason;
    NSException *except;
    
    // OK?: not in OpenStep docs but is implmented by GNUStep
    reason = [NSString stringWithFormat:format arguments:argList];
    //reason = [[NSString alloc] initWithFormat:format arguments:argList];
    //[reason autorelease];
    except = [self exceptionWithName:name reason:reason userInfo:nil];
    [except raise];
}

- (id)initWithName:(NSString *)name reason:(NSString *)reason
	  userInfo:(NSDictionary *)userInfo 
{
    self = [super init];
    e_name = [name retain];
    e_reason = [reason retain];
    e_info = [userInfo retain];
    
    return self;
}

- (volatile void)raise
{
    NSThread *thread;
    NSHandler *handler;
    
    if (_NSUncaughtExceptionHandler == NULL)
        _NSUncaughtExceptionHandler = _NSFoundationUncaughtExceptionHandler;

    thread = [NSThread currentThread];
    handler = thread->_exception_handler;
    if (handler == NULL) {
    	_NSUncaughtExceptionHandler(self);
	return;
    }

    thread->_exception_handler = handler->next;
    handler->exception = self;
    longjmp(handler->jumpState, 1);
}

- (NSString *)name
{
    return e_name;
}

- (NSString *)reason
{
    return e_reason;
}

- (NSDictionary *)userInfo
{
    return e_info;
}


- (void)encodeWithCoder: aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:e_name]; 
    [aCoder encodeObject:e_reason]; 
    [aCoder encodeObject:e_info]; 
}

- (id)initWithCoder: aDecoder
{
    self = [super initWithCoder:aDecoder];
    e_name = [[aDecoder decodeObject] retain]; 
    e_reason = [[aDecoder decodeObject] retain]; 
    e_info = [[aDecoder decodeObject] retain]; 
    return self;
}

- deepen
{
    e_name = [e_name copyWithZone:[self zone]];
    e_reason = [e_reason copyWithZone:[self zone]];
    e_info = [e_info copyWithZone:[self zone]];
    return self;
}

- copyWithZone:(NSZone *)zone
{
    if (NSShouldRetainWithZone(self, zone))
    	return [self retain];
    else
    	return [[super copyWithZone:zone] deepen];
}


@end


void 
_NSAddHandler( NSHandler *handler )
{
    NSThread *thread;

    thread = [NSThread currentThread];
    handler->next = thread->_exception_handler;
    thread->_exception_handler = handler;
}

void 
_NSRemoveHandler( NSHandler *handler )
{
    NSThread *thread;

    thread = [NSThread currentThread];
    thread->_exception_handler = thread->_exception_handler->next;
}

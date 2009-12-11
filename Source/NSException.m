/** NSException - Object encapsulation of a general exception handler
   Copyright (C) 1993, 1994, 1996, 1997, 1999 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Mar 1995

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

   $Date$ $Revision$
*/

#import "config.h"
#import "GSPrivate.h"
#import "GNUstepBase/preface.h"
#import <Foundation/NSDebug.h>
#import <Foundation/NSBundle.h>
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSString.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSNull.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSValue.h"
#include <stdio.h>
#ifdef HAVE_BACKTRACE
#include <execinfo.h>
#endif


#define _e_info (((id*)_reserved)[0])
#define _e_stack (((id*)_reserved)[1])

typedef struct { @defs(NSThread) } *TInfo;

/* This is the GNU name for the CTOR list */

Class GSStackTraceClass;

@interface GSStackTrace : NSObject
{
  void	**addresses;
  NSArray *addressArray;
  NSArray *symbols;
  int count;
}
- (NSArray*) addresses;
- (NSArray*) symbols;
@end
@interface NSException (StackTracePrivate)
- (GSStackTrace*)_callStack;
@end

#ifdef HAVE_BACKTRACE


@implementation GSStackTrace : NSObject
+ (void)load
{
  GSStackTraceClass = self;
}
+ (GSStackTrace*) currentStack
{
  return [[[GSStackTrace alloc] init] autorelease];
}
- (void)finalize
{
  free(addresses);
}
- (oneway void) dealloc
{
  free(addresses);
  RELEASE(addressArray);
  RELEASE(symbols);
  [super dealloc];
}

- (NSString*) description
{
  NSMutableString *trace = [NSMutableString string];
  NSEnumerator *e = [[self symbols] objectEnumerator];
  int i = 0;
  id obj;

  while ((obj = [e nextObject]))
    {
      [trace appendFormat: @"%d: %@\n", i++, obj];
    }
  return trace;
}

- (NSArray*) symbols
{
  if (nil == symbols) 
    {
      char	**strs = backtrace_symbols(addresses, count);
      NSString	**symbolArray = alloca(count * sizeof(NSString*));
      int i;

      for (i = 0; i < count; i++)
	{
	  symbolArray[i] = [NSString stringWithUTF8String: strs[i]];
	}
      symbols = [[NSArray alloc] initWithObjects: symbolArray
					   count: count];
      free(strs);
    }
  return symbols;
}

- (NSArray*)addresses
{
  if (nil == addressArray)
    {
      NSNumber **addrs = alloca(count * sizeof(NSString*));
      int i;

      for (i = 0; i < count; i++)
	{
	  addrs[i] = [NSNumber numberWithUnsignedInteger:
	    (NSUInteger)addresses[i]];
	}
      addressArray = [[NSArray alloc] initWithObjects: addrs
						count: count];
    }
  return addressArray;
}
// grab the current stack 
- (id) init
{
  if (nil == (self = [super init])) { return nil; }
  addresses = calloc(sizeof(void*),1024);
  count = backtrace(addresses, 1024);
  addresses = realloc(addresses, count);
  return self;
}

@end

#endif

NSString* const NSCharacterConversionException
  = @"NSCharacterConversionException";

NSString* const NSGenericException
  = @"NSGenericException";

NSString* const NSInternalInconsistencyException
  = @"NSInternalInconsistencyException";

NSString* const NSInvalidArgumentException
  = @"NSInvalidArgumentException";

NSString* const NSMallocException
  = @"NSMallocException";

NSString* const NSOldStyleException
  = @"NSOldStyleException";

NSString* const NSParseErrorException
  = @"NSParseErrorException";

NSString* const NSRangeException
 = @"NSRangeException";

static void _terminate()
{
  BOOL	shouldAbort;

#ifdef	DEBUG
  shouldAbort = YES;		// abort() by default.
#else
  shouldAbort = NO;		// exit() by default.
#endif
  shouldAbort = GSPrivateEnvironmentFlag("CRASH_ON_ABORT", shouldAbort);
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
  CREATE_AUTORELEASE_POOL(pool);
  fprintf(stderr, "%s: Uncaught exception %s, reason: %s\n",
    GSPrivateArgZero(),
    [[exception name] lossyCString], [[exception reason] lossyCString]);
  fflush(stderr);	/* NEEDED UNDER MINGW */
  if (GSPrivateEnvironmentFlag("GNUSTEP_STACK_TRACE", NO) == YES)
    {
      fprintf(stderr, "Stack\n%s\n",
	[[[exception _callStack] description] lossyCString]);
    }
  fflush(stderr);	/* NEEDED UNDER MINGW */
  RELEASE(pool);
  _terminate();
}

static  NSUncaughtExceptionHandler *_NSUncaughtExceptionHandler
  = _NSFoundationUncaughtExceptionHandler;

#if	!defined(_NATIVE_OBJC_EXCEPTIONS) || defined(HAVE_UNEXPECTED)
static void
callUncaughtHandler(id value)
{
  if (_NSUncaughtExceptionHandler != NULL)
    {
      (*_NSUncaughtExceptionHandler)(value);
    }
  _NSFoundationUncaughtExceptionHandler(value);
}
#endif


@implementation NSException

+ (void) initialize
{
#if	defined(_NATIVE_OBJC_EXCEPTIONS) && defined(HAVE_UNEXPECTED)
  objc_set_unexpected(callUncaughtHandler);
#endif
  return;
}

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
  // This probably doesn't matter, but va_end won't get called
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
  if (_reserved == 0)
    {
      _reserved = NSZoneCalloc([self zone], 2, sizeof(id));
    }
  if (userInfo != nil)
    {
      ASSIGN(_e_info, userInfo);
    }
  _e_stack = [GSStackTraceClass new];
  return self;
}
- (id) init
{
  return [self initWithName: NSGenericException 
                     reason: @"No reason" 
                   userInfo: nil];
}

- (NSArray*) callStackReturnAddresses
{
  return [_e_stack addresses];
}
- (NSArray *) callStackSymbols
{
  return [_e_stack symbols];
}
- (GSStackTrace*)_callStack
{
  return _e_stack;
}

- (void) dealloc
{
  DESTROY(_e_name);
  DESTROY(_e_reason);
  if (_reserved != 0)
    {
      DESTROY(_e_info);
      DESTROY(_e_stack);
      NSZoneFree([self zone], _reserved);
      _reserved = 0;
    }
  [super dealloc];
}

- (void) raise
{
#ifndef _NATIVE_OBJC_EXCEPTIONS
  TInfo         thread;
  NSHandler	*handler;
#endif

  if (_reserved == 0)
    {
      _reserved = NSZoneCalloc([self zone], 2, sizeof(id));
    }

#ifdef _NATIVE_OBJC_EXCEPTIONS
  @throw self;
#else
  thread = (TInfo)GSCurrentThread();
  handler = thread->_exception_handler;
  if (handler == NULL)
    {
      static	int	recursion = 0;

      /*
       * Set/check a counter to prevent recursive uncaught exceptions.
       * Allow a little recursion in case we have different handlers
       * being tried.
       */
      if (recursion++ > 3)
	{
	  fprintf(stderr,
	    "recursion encountered handling uncaught exception\n");
	  fflush(stderr);	/* NEEDED UNDER MINGW */
	  _terminate();
	}

      /*
       * Call the uncaught exception handler (if there is one).
       */
      callUncaughtHandler(self);

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
#endif
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
  if (_reserved == 0)
    {
      return nil;
    }
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
  id    info = (_reserved == 0) ? nil : _e_info;

  [aCoder encodeValueOfObjCType: @encode(id) at: &_e_name];
  [aCoder encodeValueOfObjCType: @encode(id) at: &_e_reason];
  [aCoder encodeValueOfObjCType: @encode(id) at: &info];
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  id    info;

  [aDecoder decodeValueOfObjCType: @encode(id) at: &_e_name];
  [aDecoder decodeValueOfObjCType: @encode(id) at: &_e_reason];
  [aDecoder decodeValueOfObjCType: @encode(id) at: &info];
  if (info != nil)
    {
      if (_reserved == 0)
        {
          _reserved = NSZoneCalloc([self zone], 2, sizeof(id));
        }
      _e_info = info;
    }
  return self;
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    {
      return RETAIN(self);
    }
  else
    {
      return [[[self class] alloc] initWithName: [self name]
                                         reason: [self reason]
                                       userInfo: [self userInfo]];
    }
}

- (NSString*) description
{
  CREATE_AUTORELEASE_POOL(pool);
  NSString      *result;

  if (_reserved != 0)
    {
      if (_e_stack != nil
        && GSPrivateEnvironmentFlag("GNUSTEP_STACK_TRACE", NO) == YES)
        {
          id    o = _e_stack;

          if (_e_info != nil)
            {
              result = [NSString stringWithFormat:
                @"%@ NAME:%@ REASON:%@ INFO:%@ STACK:%@",
                [super description], _e_name, _e_reason, _e_info, o];
            }
          else
            {
              result = [NSString stringWithFormat:
                @"%@ NAME:%@ REASON:%@ STACK:%@",
                [super description], _e_name, _e_reason, o];
            }
        }
      else
        {
          result = [NSString stringWithFormat:
            @"%@ NAME:%@ REASON:%@ INFO:%@",
            [super description], _e_name, _e_reason, _e_info];
        }
    }
  else
    {
      result = [NSString stringWithFormat: @"%@ NAME:%@ REASON:%@",
        [super description], _e_name, _e_reason];
    }
  IF_NO_GC([result retain];)
  IF_NO_GC(DESTROY(pool);)
  return AUTORELEASE(result);
}

@end


void
_NSAddHandler (NSHandler* handler)
{
  TInfo thread;

  thread = (TInfo)GSCurrentThread();
#if defined(__MINGW32__) && defined(DEBUG)
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
  TInfo         thread;

  thread = (TInfo)GSCurrentThread();
#if defined(DEBUG)  
  if (thread->_exception_handler != handler)
    {
      fprintf(stderr, "ERROR: Removing exception handler that is not on top "
	"of the stack. (You probably called return in an NS_DURING block.)\n");
    }
#if defined(__MINGW32__)
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

NSUncaughtExceptionHandler *
NSGetUncaughtExceptionHandler()
{
  return _NSUncaughtExceptionHandler;
}

void
NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler *handler)
{
  _NSUncaughtExceptionHandler = handler;
}

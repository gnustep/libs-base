/* Interface for NSArray for GNUStep
   Copyright (C) 1994 NeXT Computer, Inc.
   
   This file is part of the GNU Objective C Class Library.

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

#ifndef __NSException_h_OBJECTS_INCLUDE
#define __NSException_h_OBJECTS_INCLUDE

#include <foundation/NSObject.h>
#include <setjmp.h>
#include <stdarg.h>

@class NSString;
@class NSDictionary;

@interface NSException : NSObject <NSCoding, NSCopying>
{    
  NSString *e_name;
  NSString *e_reason;
  NSDictionary *e_info;
}

+ (NSException *)exceptionWithName:(NSString *)name
	reason:(NSString *)reason
	userInfo:(NSDictionary *)userInfo;
+ (volatile void)raise:(NSString *)name
	format:(NSString *)format,...;
+ (volatile void)raise:(NSString *)name
	format:(NSString *)format
	arguments:(va_list)argList;

- (id)initWithName:(NSString *)name 
	reason:(NSString *)reason 
	userInfo:(NSDictionary *)userInfo;
- (volatile void)raise;

// Querying Exceptions
- (NSString *)name;
- (NSString *)reason;
- (NSDictionary *)userInfo;

@end

/* Common exceptions */
extern NSString *NSInconsistentArchiveException;
extern NSString *NSGenericException;
extern NSString *NSInternalInconsistencyException;
extern NSString *NSInvalidArgumentException;
extern NSString *NSMallocException;
extern NSString *NSRangeException;

/* Exception handler definitions */
typedef struct _NSHandler 
{
    jmp_buf jumpState;			/* place to longjmp to */
    struct _NSHandler *next;		/* ptr to next handler */
    NSException *exception;
} NSHandler;

typedef volatile void NSUncaughtExceptionHandler(NSException *exception);

extern NSUncaughtExceptionHandler *_NSUncaughtExceptionHandler;
#define NSGetUncaughtExceptionHandler() _NSUncaughtExceptionHandler
#define NSSetUncaughtExceptionHandler(proc) \
			(_NSUncaughtExceptionHandler = (proc))

/* NS_DURING, NS_HANDLER and NS_ENDHANDLER are always used like:

	NS_DURING
	    some code which might raise an error
	NS_HANDLER
	    code that will be jumped to if an error occurs
	NS_ENDHANDLER

   If any error is raised within the first block of code, the second block
   of code will be jumped to.  Typically, this code will clean up any
   resources allocated in the routine, possibly case on the error code
   and perform special processing, and default to RERAISE the error to
   the next handler.  Within the scope of the handler, a local variable
   called exception holds information about the exception raised.

   It is illegal to exit the first block of code by any other means than
   NS_VALRETURN, NS_VOIDRETURN, or just falling out the bottom.
 */

/* private support routines.  Do not call directly. */
extern void _NSAddHandler( NSHandler *handler );
extern void _NSRemoveHandler( NSHandler *handler );

#define NS_DURING { NSHandler NSLocalHandler;			\
		    _NSAddHandler(&NSLocalHandler);		\
		    if( !setjmp(NSLocalHandler.jumpState) ) {

#define NS_HANDLER _NSRemoveHandler(&NSLocalHandler); } else { \
		    NSException *exception = NSLocalHandler.exception;

#define NS_ENDHANDLER }}

#define NS_VALRETURN(val)  do { typeof(val) temp = (val);	\
			_NSRemoveHandler(&NSLocalHandler);	\
			return(temp); } while (0)

#define NS_VOIDRETURN	do { _NSRemoveHandler(&NSLocalHandler);	\
			return; } while (0)

#endif /* __NSException_h_OBJECTS_INCLUDE */

/* Exception.h      -*-objc-*-
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */

/* Exceptions are organized in a tree like hierarchy, where a protocol
 * represents a type of error. This decouples the hierarchy of error
 * types from the inheritance hierarchy of implementations. As an extra
 * bonus, some kind of "multiple inheritance" is possible.
 *
 * The most important branch of this hierarchy is the type AnyError and
 * its descendants. Errors abort the program if they are raised but not
 * caught.
 *
 * In contrast, there may be other kinds of exceptions, of type
 * AnyException but not AnyError, which are simply ignored if they are
 * raised and not catched.
 *
 * This file defines the classes that implement raising of exceptions,
 * and also defines an first outline of an exception hierarchy.
 *
 * One might integrate catch and throw into this hierarchy too,
 * but I don't think that's a good idea. */

/* Name conventions: Error types (that is, protocols) end in "Error".
 * A class implementing a particular error has a descriptive name, for
 * example "OutOfMemory" or "ThrowWithoutCath". */

#ifndef OBJC_EXCEPTION_H_INCLUDED
#define OBJC_EXCEPTION_H_INCLUDED

#include <Foundation/NSObject.h>
#include <objects/Catch.h>

/* Having signals cause exceptions requires some more thought.
 * Disabled for now. */
#define WITH_SIGNALS 0

#if WITH_SIGNALS
#include <signal.h>
#endif

/* Perhaps this should be a plain id instead? */
typedef Protocol * exception_type; 

/* Protocols for the error hierarchy */

@protocol AnyException
- (void) raise;           /* Usually does not return */
- (const char *) message; /* Human readable description */
- (void) finished;        /* Should be sent by a handler when
			   * finished with the exception. */
- (BOOL) ofExceptionType: (exception_type) type;
- (void) noHandler;       /* Sent if raise can't find a handler */
@end /* AnyException */

@protocol AnyError <AnyException>
@end /* AnyError */

@protocol StorageError <AnyError>
@end /* StorageError */

@protocol MemoryError <StorageError>
@end /* MemoryError */

@protocol ThrowError <AnyError>
- tag;
- tag: newTag;
- value;
- value: newValue;
@end /* ThrowError */

#if WITH_SIGNALS
@protocol SignalException <AnyException>
- (int) signal;
- signal: (signal);
@end /* SignalException */
#endif

/* Classes for some exceptions */

/* Exceptions may be raised when certain things happen to the program,
 * for example when memory allocation fails, or the process recieves
 * a signal. Exceptions for these conditions are can be installed so far:
 */

enum exception_condition
{
  Exc_MemoryExhausted = 1,
  /* FIX: converting signals to exceptions is not reliable.
   * I don't touch the signal mask anywhere in the code, which is
   * probably necessary. And I have no idea how to properly
   * longjmp() out of a signal handler. */
  Exc_Signal = 1024, /* Add signal number */
};

@interface Exception : NSObject <AnyException>
{
}
/* Tries to install exception handler for condition COND.
 * Returns YES on success. */
+ (BOOL) addExceptionOn: (enum exception_condition) cond;
+ (BOOL) removeExceptionOn:(enum exception_condition) cond;
@end /* Exception */

@interface Error: Exception <AnyError>
@end /* Error */

@interface SimpleError : Error
{
  const char *message;
  BOOL constantMessage;
  BOOL constantObject;
}
- message: (const char *) msg;

/* FALSE means don't free the message string */
- constantMessage: (BOOL) flag;

/* TRUE means ignore the -finished message */
- constant: (BOOL) flag;
@end /* SimpleError */

/* This kind of error is usually allocated at startup, and never released.
 * This is so that no memory allocation is needed to signal that the
 * program has run out of memory. */
@interface OutOfMemory : SimpleError <StorageError>
+ newMessage: (const char *) msg;
@end /* OutOfMemory */

@interface ThrowWithoutCatch : Error <ThrowError>
{
  id value;
  id tag;
}
@end

#if WITH_SIGNALS
/* With the first class, the signal is ignored if not caught,
 * with the second class it isn't */
@interface SignalWarning : Exception <SignalException>
- int sig;
@end /* SignalWarning */

@interface SignalError : SignalWarning <AnyError>
@end /* SignalError */
#endif

/* Catching exceptions */
@interface CatchException : Catch_common
{
  id exception;
  exception_type exceptionType;
}
- (JMP_BUF *) catch: type;
- exceptionType;
- exceptionType: type;
- exception;
- exception: object;
@end /* CatchException */


/* Macros
 *
 * For your information: I was really ambivalent about how the
 * interface to exceptions should be designed. At last, I decided
 * to use macros with blocks as arguments, instead of the NextStep
 * style with NS_* macros to start and end the blocks.
 *
 * One main reason is that I want as few macro names to invent and
 * remember as possible.
 */

/* TRY macro
 *
 * Executes the BODY, catching TYPE exceptions. If an exception
 * happens, VAR is bound to the exception, and HANDLER is
 * executed. When finished with the exception, you should send
 * it the `finished' message.
 *
 * Usage:
 *
 * id error;
 * TRY({
 *        body
 *     },
 *     @protocol(IOError), error,
 *     {
 *        [error something];
 *        [error finished];
 *     });
 */

#define TRY(body, type, var, handler) do { \
  id _TRY_tag = [[CatchException alloc] init]; \
  if (SETJMP(*[_TRY_tag catch: type]) == 0) \
    {\
       body \
       [_TRY_tag release];\
    } \
  else \
    {\
      (var) = [_TRY_tag exception]; \
      [_TRY_tag release];\
      handler \
    } \
} while(0)

#endif OBJC_EXCEPTION_H_INCLUDED

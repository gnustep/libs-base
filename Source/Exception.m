/* Exception.m      -*-objc-*-
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */

#include <objects/Exception.h>
#include <objects/Catch.h>
#include <objects/objc-malloc.h>
#include <objc/objc-api.h>
#include <stdlib.h>

#include <assert.h>
#define CANT_HAPPEN assert(0)

#define FRAME_STACK StackFrame

/* Special exception handlers */

/* This exception is raised if allocation of a new object fails */
id <AnyException>
alloc_exception = nil;

static void
handle_out_of_memory(void)
{
  if (alloc_exception)
    [alloc_exception raise];
}

#if WITH_SIGNALS
/* Handle signals */
static void
signal_raise_warning(int signal)
{
  [[[SignalWarning new] signal: signal] raise];
}

static void
signal_raise_error(int signal)
{
  [[[SignalError new] signal: signal] raise];
}
#endif

@implementation Exception
+ (BOOL) addExceptionOn: (enum exception_condition) cond
{
#if 0
  /* If cond > Exc_Signal, trap the corresponding UNIX signal) */
  if (cond > Exc_Signal)
    return (signal(cond - Exc_Signal, signal_raise_error) != SIG_ERR);
#endif
  
  switch (cond)
    {
    case Exc_MemoryExhausted:
      if (objc_out_of_memory_hook)
	/* Some hook already installed. Don't touch it, and return
	 * sucessfully if it is us. */
	return (objc_out_of_memory_hook == handle_out_of_memory);
      if (!alloc_exception)
	alloc_exception
	  = [OutOfMemory
	      newMessage: "objc: Virtual memory exhausted"];
      objc_out_of_memory_hook = handle_out_of_memory;
      return YES;
    default:
      return NO;
    }
  return NO;
}

+ (BOOL) removeExceptionOn: (enum exception_condition) cond
{
#if 0
  /* If cond > Exc_Signal, trap the corresponding UNIX signal) */
  if (cond > Exc_Signal)
    return (signal(cond - Exc_Signal, SIG_DFL) != SIG_ERR);
#endif

  switch (cond)
    {
    case Exc_MemoryExhausted:
      if (objc_out_of_memory_hook == handle_out_of_memory)
	{
	  objc_out_of_memory_hook = NULL;
	  return YES;
	}
      return NO;
    default:
      return NO;
    }
  return NO;
}

- (void) raise
{
  frame_id frame;
  id catch;

  frame = [FRAME_STACK findFrameMatching: self];
  if (frame)
    {
      catch = ( (struct frstack_catch_object_frame *) frame)->object;
      [catch exception: self];
      [FRAME_STACK unwind: frame pleaseReturn: NO];
      CANT_HAPPEN;
    }
  [self noHandler];
}


- (BOOL) ofExceptionType: (exception_type) type
{
  return [self conformsToProtocol: type];
}


- (const char *) message
{
  /* Default message is name of class */
  return object_get_class_name (self);
}

- (void) noHandler { return; }

- (void) finished { [self release]; }
@end /* Exception */


@implementation Error
- (void) noHandler
{
  /* No handler for this error. Exit program. */
  [self error: "No catcher for error: %s.\n", [self message]];
}
@end /* Error */


@implementation SimpleError
- message: (const char *) msg { message = msg; return self; }

- constantMessage: (BOOL) flag { constantMessage = flag; return self; }

- constant: (BOOL) flag { constantObject = flag; return self; }

- (void) finished
{
  if (!constantObject)
    [self release];
}

- (void) dealloc
{
  if (!constantMessage)
    free((char *)message);
  [super dealloc];
}
@end /* SimpleError */


@implementation OutOfMemory
+ newMessage: (const char *) msg
{
  id me = [super new];
  [me message: msg];
  [me constantMessage: YES];
  [me constant: YES];
  return me;
}
@end /* OutOfMemory */


@implementation ThrowWithoutCatch
- value { return value; }

- value: newValue { value = newValue; return self; }

- tag { return tag; }

- tag: newTag { tag = newTag; return self;}

- (const char *) message
{
  return "A throw was attempted, without a matching catch.";
}
@end /* ThrowWithoutCatch */

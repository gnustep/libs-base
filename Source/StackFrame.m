/* StackFrame.m
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */

#include <objects/StackFrame.h>
#include <objects/Catching.h>
#include <objects/Exception.h>
#include <stdlib.h>

/* Object interfacing to the functions in frame_stack.c */
#define FRAME_STACK StackFrame


/* Global data */
static int
cleanup_on_exit = 0;

static id <AnyException>
out_of_memory_exception = nil;


/* For compatibility with ccatch.c */
void
init_catch(void)
{
  /* Call a dummy method, to make sure that the class is initialized */
  [FRAME_STACK dummy_init];
}

/* Private functions */
static void
catch_on_exit(void)
{
  if (cleanup_on_exit)
    {
      frstack_unwind(NULL, 1);
      frstack_free(NULL);
    }
}


static void
out_of_memory(void)
{
  if (out_of_memory_exception)
    [out_of_memory_exception raise];
}


static int
cmp_match(frame_id frame, void *data)
{
  return (frame->type == frstack_catch_object)
    && [( (struct frstack_catch_object_frame *)frame)->object
	   matches: (id) data];
}


@implementation StackFrame
+ (void) initialize
{
  /* Make sure we only initialize once */
  if (self == [StackFrame class])
    {
      frstack_init();

      if (atexit(catch_on_exit) != 0)
	[self error: "atexit() failed!"];

      out_of_memory_exception
	= [OutOfMemory newMessage: "StackFrame: Out of memory"];
      the_frame_stack.on_error = out_of_memory;
      cleanup_on_exit = YES;
    }
}


+ cleanupOnExit: (BOOL) flag
{
  cleanup_on_exit = flag;
  return self;
}


+ (void) dummy_init {} /* Makes sure the class is
			* properly initialized. */


+ (frame_id) pushCatch: object
{
  return fr_catch_object_setup(object);
}


+ (frame_id) pushCleanupSending: (SEL) selector to: reciever
{
  return fr_cleanup_object(reciever, selector);
}


+ (frame_id) pushCleanupCall: (void (*)(void)) function
{
  return fr_cleanup_fn0(function);
}
  

+ (frame_id) pushCleanupCall: (void (*)(void *)) function with: (void *) arg
{
  return fr_cleanup_fn1(function, arg);
}


+ (frame_id) pushCleanup_jmp
{
  return fr_cleanup_jmp_setup();
}


+ (void) unwindContinue: (frame_id) target
{
  frstack_continue(target);
}


+ (frame_id) findFrameMatching: object;
{
  return frstack_find_frame(cmp_match, (void *) object);
}


+ (void) unwind: (frame_id) target pleaseReturn: (BOOL) flag
{
  frstack_unwind(target, flag);
}


+ (void) freeFrame: (frame_id) fr
{
  frstack_free(fr);
}


+ (void) jumpToFrame: (frame_id) target
{
  frstack_jmp(target);
}


- (void) dealloc
{
  [self cleanup];
  [super dealloc];
}


- (void) cleanup
{
  if (frame)
    [FRAME_STACK freeFrame: frame];
  frame = NULL;
}

@end /* StackFrame */

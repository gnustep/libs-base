/* StackFrame.h             -*-objc-*-
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */

#ifndef STACKFRAME_H_INCLUDED
#define STACKFRAME_H_INCLUDED

#include <Foundation/NSObject.h>
#include <frame_stack.h>


/* This exception is raised by new xmalloc if memory allocation fails. */
extern id
xmalloc_exception;


@interface StackFrame : NSObject
{
  frame_id frame;
}
+ (void) dummy_init; /* Dummy method, used to make sure the stack is
		      * initialized. */
+ cleanupOnExit: (BOOL) flag;
+ (frame_id) pushCatch: object;  /* Requires a SETJMP() to take effect. */
+ (frame_id) pushCleanupSending: (SEL) selector to: reciever;
+ (frame_id) pushCleanupCall: (void (*)(void)) function;
+ (frame_id) pushCleanupCall: (void (*)(void *)) function with: (void *) arg;
+ (frame_id) pushCleanup_jmp;    /* Requires a SETJMP() to take effect. */
+ (void) unwindContinue: (frame_id) target;
+ (frame_id) findFrameMatching: object;
+ (void) unwind: (frame_id) target pleaseReturn: (BOOL) flag;
+ (void) freeFrame: (frame_id) frame;
+ (void) jumpToFrame: (frame_id) target;
- (void) cleanup;

@end /* StackFrame */

#endif STACKFRAME_H_INCLUDED


/* UnwindProtect.m
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */


#include <objects/UnwindProtect.h>

/* Object interfacing to the functions in frame_stack.c */
#define FRAME_STACK StackFrame


@implementation UnwindProtect 
- init
{
  [ [self initNoMagic] cleanupBySending: @selector(release) to: self];
  return self;
}

- initNoMagic
{
  [super init];
  frame = NULL;
  return self;
}

- cleanupByCalling: ( void (*)(void)) function
{
  frame_id newFrame = [FRAME_STACK pushCleanupCall: function];
  if (!frame)
    frame = newFrame;
  return self;
}

- cleanupByCalling: ( void (*)(void *)) function with: (void *) argument
{
  frame_id newFrame = [FRAME_STACK pushCleanupCall: function
				   with: argument];
  if (!frame)
    frame = newFrame;
  return self;
}

- cleanupBySending: (SEL) message to: rec
{
  frame_id newFrame = [FRAME_STACK pushCleanupSending: message to: rec];
  if (!frame)
    frame = newFrame;
  return self;
}

- (JMP_BUF *) cleanupByJumpingHere: (frame_id *) framepointer
{
  frame_id newFrame = [FRAME_STACK pushCleanup_jmp];
  if (!frame)
    frame = newFrame;
  *framepointer = newFrame;
  return &(( (struct frstack_cleanup_jmp_frame *) newFrame)->where);
}
  
- (void) cleanup
{
  /* This may be a little tricky:
   * (i) dealloc sends the cleanup message, and
   * (ii) unwinding the stack may send us the release message.
   *
   * To avoid problems, make sure that unwinding happens at most once.
   */
  if (frame)
    {
      frame_id old_frame = frame;
      frame = 0;
      frstack_unwind(old_frame, YES);
    }
}

@end /* UnwindProtect */

/* UnwindProtect.h       -*-objc-*-
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */

#ifndef UNWINDPROTECT_H_INCLUDED
#define UNWINDPROTECT_H_INCLUDED

#include <objects/StackFrame.h>
#include <objects/Catch.h>

/* NOTE: Cleanup actions registered with cleanupByJumpingHere 
 * will *not* be called automatically if the program exit()s, nor
 * as a result of a cleanup message. */

/* UnwindProtect
 * -------------
 *
 * id tag = [UnwindProtect new];
 *
 * [tag cleanupByCalling: someFunction];
 * [tag cleanupByCalling: someFunction with: argument];
 * [tag cleanupBySending: someSelector to: someObject];
 * if (set_catch([tag cleanupByJumpingHere]))
 * {
 *    ... cleanup code ...
 *    [tag continue];
 * }
 * else
 * {
 *    ... body ...
 *
 * }
 *
 * [tag cleanup];
 *
 * Any number of cleanup actions are allowed.
 */

@interface UnwindProtect : StackFrame

/* By default, releasing this object itself is done automatically when
 * cleaning up. If you don't want this, use
 * [[UnwindProtect alloc] initNoMagic] instead of [UnwindProtect new].
 */
- initNoMagic;
- cleanupByCalling: ( void (*)(void)) function;
- cleanupByCalling: ( void (*)(void *)) function with: (void *) argument;
- cleanupBySending: (SEL) message to: rec;
- (JMP_BUF *) cleanupByJumpingHere: (frame_id *) framepointer;
- (void) cleanup;
@end

/* About freeing the UnwindProtect instance created below:
 *
 * If stack unwinding is progress, unwindContinue won't return, and the
 * object is released as an effect of the earlier cleanupBySending...
 * message.
 *
 * If there's no stack unwinding happening, unwindContinue returns
 * without doing anything, and we explicitly release the object.
 */
#define UNWINDPROTECT(body, cleanup_code) do {\
  frame_id _UNWIND_PROTECT_frame; \
  id _PROTECT_tag = [UnwindProtect alloc]; \
  if (SETJMP(*[_PROTECT_tag \
		cleanupByJumpingHere: &_UNWIND_PROTECT_frame])==0) \
    body \
  cleanup_code \
  [[_PROTECT_tag class] unwindContinue: _UNWIND_PROTECT_frame]; \
  [_PROTECT_tag release]; \
} while (0)

#endif UNWINDPROTECT_H_INCLUDED

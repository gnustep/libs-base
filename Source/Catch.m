/* Catch.m
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */

#include <objects/Catch.h>
#include <objects/Exception.h>

#include <assert.h>
#define CANT_HAPPEN assert(1)

/* Object interfacing to the functions in frame_stack.c */
#define FRAME_STACK StackFrame

@implementation Catch_common
- (JMP_BUF *) where { return &where; } 
- (JMP_BUF *) catch;
{
  /* Allow reuse, without explicit cleanup. */
  if (frame)
    [self cleanup];
  frame = [FRAME_STACK pushCatch: self];
  return [self where];
}

- (void) jump
{
  LONGJMP(*[self where], 42);
}

- (BOOL) matches: object
{
  [self subclassResponsibility: @selector(matches)];
  return NO; /* Not reached */
}
@end /* Catch_common */

@implementation Catch
- value { return result; }
- value: newValue { result = newValue; return self; }

- (BOOL) matches: tag
{
  /* It's possible to send throw to a object distinct from the Catch
   * object, if that object pretends it's equal to the Catch object.
   */
  return [tag isEqual: self];
}

- (void) throw: value
{
  [self throw: value release: YES];
}

- (void) throw: value release: (BOOL) releaseFlag
{
  frame_id fr;
  id catch;
  
  fr = [FRAME_STACK findFrameMatching: self];
  if (fr)
    {
      catch = ( (struct frstack_catch_object_frame *) fr)->object;
      [catch value: value];

      /* If releaseFlag is true, and we are not the same object as the one
       * used in the catch, release. */
      if (releaseFlag && !(catch == self))
	[self release];
      [FRAME_STACK unwind: fr pleaseReturn: NO];

      CANT_HAPPEN;
    }

  /* No matching catch found. Try signalling an error. */
  
  [[[[ThrowWithoutCatch new] value: value] tag: self] raise];
  CANT_HAPPEN;
}
@end /* Catch */


@implementation CatchException
- exceptionType { return exceptionType; }
- exceptionType: type { exceptionType = type; return self; }
- exception { return exception; }
- exception: object { exception = object; return self; }

- (JMP_BUF *) catch: type
{
  return [ [self exceptionType: type] catch];
}

- (BOOL) matches: tag
{
  return [tag conformsToProtocol: @protocol(AnyException)]
    && [tag ofExceptionType: exceptionType];
}

/* For now, deallocating the CatchException does not
 * attempt to release any caught exception.
 */
#if 0
- (void) dealloc
{
  if (exception) [exception finished];
  [super dealloc];
}
#endif

@end /* CatchException */

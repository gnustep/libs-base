/* Catch.h          -*-objc-*-
 *
 * catch and throw for Objective-C programs.
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */

#ifndef CATCH_OBJC_H_INCLUDED
#define CATCH_OBJC_H_INCLUDED

#include <objects/StackFrame.h>
#include <objects/Catching.h>

@interface Catch_common : StackFrame  <Catching>
{
  JMP_BUF where;
}
- (JMP_BUF *) where;
- (JMP_BUF *) catch;
@end /* Catch_common */


@interface Catch : Catch_common
{
  id result;
}
- value;
- value: newValue;
- (void) throw: value;
- (void) throw: value release: (BOOL) releaseFlag;
@end /* Catch */


/* Macros */
   
/* CATCH
 *
 * Exceutes the block BODY, catching any throws to the tag TAG.
 * The value is 1 if a throw happened, otherwise 0. In the first case,
 * [TAG value] gives the value from the throw.
 *
 * Allocation and freeing of TAG, which should be a Catch object,
 * is not done by the CATCH macro.
 *
 * Usage
 * ~~~~~
 * tag = [[Catch alloc] init];
 * if (CATCH(tag,
 *          {
 *            ...
 *          }))
 *    printf("Caught throw, value = %s\n", [[tag value] something]);
 * else
 *    printf("Done\n");
 * [tag free];
 */
 
#define CATCH(tag, body) \
( SETJMP(*[(tag) catch]) ? ([(tag) value], 1) : ((body), 0) )
    

#endif CATCH_OBJC_H_INCLUDED

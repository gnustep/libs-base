/* Catching.h   -*-objc-*-
 *
 * Defines the methods a catcher object must respond to, to interface
 * to the frame stack.
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */

#ifndef CATCHING_H_INCLUDED
#define CATCHING_H_INCLUDED

#include <objc/objc.h>

@protocol Catching

/* This message is sent to the object registered in a frstack_catch_object
 * frame. The argument will be a Catch, an Exception or an NSException
 * object. Should return TRUE if the frame matches OBJECT.
 */
- (BOOL) matches: object;

/* Passes control to the frame */
- (void) jump;
@end /* Catching */

#endif CATCHING_H_INCLUDED

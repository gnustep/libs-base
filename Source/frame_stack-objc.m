/* frame_stack-objc.m
 *
 * Just includes frame_stack.c, but makes sure that FRAMESTACK_OBJC is
 * defined.
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */
 
#define FRAMESTACK_OBJC

#include "frame_stack.c"


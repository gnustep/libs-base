/* frame_stack.h
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */


/* A frame stack keeps track of the information needed
 * for catch, throw and unwind-protect. */

#ifndef FRAME_STACK_H_INCLUDED
#define FRAME_STACK_H_INCLUDED

#include <stddef.h>
#include <obstack.h>

#include <SETJMP.h>

#ifdef __OBJC__
#include <objects/Catching.h>
#endif __OBJC__


/* I use two different types of catch frames to get separate
 * spaces for C tags and Objective-C tag objects.
 *
 * frstack_catch uses a pointer into the stack as tag.
 * frstack_catch_object uses a pointer to an object. When throw()ing,
 *                  the object is asked if it matches.
 */

enum frstack_types
{
  frstack_none = 0,
  frstack_ccatch,
  frstack_catch_object,
  frstack_cleanup_fn0,
  frstack_cleanup_fn1,
  frstack_cleanup_object,
  frstack_cleanup_jmp
};


struct frstack_frame
{
  enum frstack_types type;
  struct frstack_frame *up;
  /* Cleanup frames are not always freed immediately.
   * Therefore, they are marked as `abandoned' as they are
   * handled. Perhaps setting the type to frstack_none
   * would work just as well.
   */
  int abandoned;
};

typedef struct frstack_frame *frame_id;

/* Specific stack frames */
struct frstack_ccatch_frame
{
  struct frstack_frame link;
  JMP_BUF where;
  int value;
};

struct frstack_cleanup_fn0_frame
{
  struct frstack_frame link;
  void (*fn)(void);
};

struct frstack_cleanup_fn1_frame
{
  struct frstack_frame link;
  void (*fn)(void *arg);
  void *arg;
};

struct frstack_cleanup_jmp_frame
{
  struct frstack_frame link;
  JMP_BUF where;
  /* For resuming stack unwinding, after this cleanup action */
  frame_id target;
};

#ifdef __OBJC__
struct frstack_cleanup_object_frame
{
  struct frstack_frame link;
  id rec;
  SEL sel;
};

struct frstack_catch_object_frame
{
  struct frstack_frame link;
  id <Catching> object;
};

#endif __OBJC__

struct frame_stack
{
  struct obstack ob;

  /* Pointer to the latest allocated frame. */
  frame_id last;
  
  /* This function is called if cthrow finds no matching catch */
  void (*no_ccatch)(int value);
    
  /* If memeory allocation fails, call the function ON_ERROR,
   * if it is non-NULL */
  void (*on_error)();

  /* This is a little tricky. A throw can happen because of a
   * out of memory condition, which happens while we try to add
   * a function to be called when stack unwinding happens.
   *
   * In this case, the function being added should be called. But
   * as it is not yet stored on the stack, we must find it some other
   * way. */
  
  struct frstack_frame *tmp_frame;
};


extern struct frame_stack the_frame_stack;

void
frstack_init(void);

/* fr_ccatch_setup pushes a new stack frame, and allocates
 * a JMP_BUF struct for SETJMP. This frame should be freed
 * with frstack_free() at the end of the catch construct. */

frame_id
fr_ccatch_setup(void);

#ifdef __OBJC__
frame_id
fr_catch_object_setup(id obj);
#endif __OBJC__


/* cthrow never returns. If there's no matching ccatch, or something
 * else goes wrong, cthrow calls the function pointed stack->no_ccatch . */

void
fr_cthrow(frame_id tag, int value);


/* Register a function to be called if a throw unwinds
 * the stack. */

frame_id
fr_cleanup_fn0(void (*function)(void));


/* Register a function with argument to be called if a throw or
 * exception causes the stack to be unwinded.
 */

frame_id
fr_cleanup_fn1(void (*function)(void *arg), void *arg);

/* Register cleanup code to LONGJMP() to. */
frame_id
fr_cleanup_jmp_setup(void);

#ifdef __OBJC__
/* Register an object and a message to it be sent if the stack is
 * unwinded. */
frame_id
fr_cleanup_object(id object, SEL message);
#endif __OBJC__

/* To be called at the end of a cleanup_jmp handler, that is, after a
 * handler that was given control by a LONGJMP(). If a throw is in
 * progress, it is continued. */
void
frstack_continue(frame_id frame);

/* Unwinds stack, calling any registered functions, until
 * the target frame is found. Does not deallocate any of the frames.
 *
 * NOTE!! This function may or may not return! Before calling, you must
 * set up any information needed for frstack_continue() and frstack_jmp()
 * to finish the job.
 *
 * If PLEASE_RETURN is true, the function refuses to LONGJMP() away
 * to cleanup actions or to any target frame. */
void
frstack_unwind(frame_id target, int please_return);

/* Passes control to a frame, which must be of some catch type. */
void
frstack_jmp(frame_id frame);

/* Return the most recent frame f such that cmp(f, data) is true.
 * No cleanup or deallocation is done. NULL is returned if no
 * matching frame is found. */
frame_id
frstack_find_frame(int (*cmp)(frame_id f, void *d),
		   void *data);

/* Only deallocates frames, no other cleanup is done.
 * A frame_id of NULL deallocates all frames. */
void
frstack_free(frame_id frame);

#endif FRAME_STACK_H_INCLUDED

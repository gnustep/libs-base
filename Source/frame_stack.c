/* frame_stack.c         -*-objc-*-
 *
 * A frame stack keeps track of the information needed for
 * catch, throw and unwind-protect.
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */

/* This source file supports both ANSI-C and Objective-C.
 * If compiled with a C-compiler, only C is supported.
 * Compile it with an Objective-C compiler, defining FRAMESTACK_OBJC,
 * to get Objective-C support as well.
 */


#include <frame_stack.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#ifdef FRAMESTACK_OBJC
#include <Foundation/NSObject.h>
#include <objects/Catching.h>
#endif FRAMESTACK_OBJC

#include <assert.h>
#define CANT_HAPPEN assert(1)

#define obstack_chunk_alloc frame_stack_alloc
#define obstack_chunk_free free


/* The global frame stack */
struct frame_stack
the_frame_stack;


/* Some private functions */

static void *
frame_stack_alloc(size_t size);

/* Unwind a single stack frame, calling it's cleanup function,
 * if there is one. */
static void
frstack_unwind_one_frame(frame_id frame, frame_id target, int please_return);

/* Links a frame to the stack. */
static void
frstack_add_frame(frame_id frame);

static int
cmp_eq(frame_id f, void *d)
{
  return (f == d);
}


/* Initialize the frame stack and the underlying obstack */
void
frstack_init(void)
{
  static int only_once = 0;

  if (!only_once)
    {
      only_once = 1;
      memset(&the_frame_stack, 0, sizeof(the_frame_stack));
      obstack_init(&(the_frame_stack.ob));
    }
}


/* Link a new frame onto the stack */
static void
frstack_add_frame(frame_id frame)
{
  frame->up = the_frame_stack.last;
  frame->abandoned = 0;
  the_frame_stack.last = frame;
}


frame_id
fr_ccatch_setup(void)
{
  frame_id frame;

  frame = obstack_alloc(&(the_frame_stack.ob),
			sizeof(struct frstack_ccatch_frame));
  
  frame->type = frstack_ccatch;

  frstack_add_frame(frame);
  return frame;
}


#ifdef FRAMESTACK_OBJC
frame_id
fr_catch_object_setup(id <Catching> obj)
{
  frame_id frame;

  frame = obstack_alloc(&(the_frame_stack.ob),
			sizeof(struct frstack_catch_object_frame));
  
  frame->type = frstack_catch_object;
  frstack_add_frame(frame);

  ( (struct frstack_catch_object_frame *) frame)->object = obj;
  
  return frame;
}
#endif FRAMESTACK_OBJC


void
fr_cthrow(frame_id tag, int value)
{
  /* Perhaps there's no real need to do this search.
   * p should always equal tag. */
  frame_id p;

  p = frstack_find_frame(cmp_eq, tag);
  ( (struct frstack_ccatch_frame *) p)->value = value;
  
  if (p)
    {
      frstack_unwind(p, 0);
      CANT_HAPPEN;
    }

  /* No matching catch found */
  if (the_frame_stack.no_ccatch)
    (*(the_frame_stack.no_ccatch))(value);

  /* No default handler either */
  fprintf(stderr, "frame_stack: throw without catch\n");
  abort();
}

frame_id
fr_cleanup_fn0(void (*function)(void))
{
  frame_id frame;
  struct frstack_cleanup_fn0_frame tmp;
  
  /* For error recovery in case obstack_alloc fails when allocating
   * another stack frame */
  the_frame_stack.tmp_frame = (frame_id) &tmp;
  tmp.link.type = frstack_cleanup_fn0;
  tmp.fn = function;
  
  frame = obstack_alloc(&(the_frame_stack.ob),
			sizeof(struct frstack_cleanup_fn0_frame));

  the_frame_stack.tmp_frame = NULL;
  
  frame->type = frstack_cleanup_fn0;
  frstack_add_frame(frame);
  
  ( (struct frstack_cleanup_fn0_frame *) frame)->fn = function;
  return frame;
}

frame_id
fr_cleanup_fn1(void (*function)(void *arg), void *arg)
{
  frame_id frame;
  struct frstack_cleanup_fn1_frame tmp;
  
  /* For error recovery in case obstack_alloc fails when allocating
   * another stack frame */
  the_frame_stack.tmp_frame = (frame_id) &tmp;
  tmp.link.type =  frstack_cleanup_fn1;
  tmp.fn = function;
  tmp.arg = arg;
  
  frame = obstack_alloc(&(the_frame_stack.ob),
			sizeof(struct frstack_cleanup_fn1_frame));

  the_frame_stack.tmp_frame = NULL;
  
  frame->type = frstack_cleanup_fn1;
  frstack_add_frame(frame);
  
  ( (struct frstack_cleanup_fn1_frame *) frame)->fn = function;
  ( (struct frstack_cleanup_fn1_frame *) frame)->arg = arg;
  return frame;
}

frame_id
fr_cleanup_jmp_setup(void)
{
  frame_id frame;

  frame = obstack_alloc(&(the_frame_stack.ob),
			sizeof(struct frstack_cleanup_jmp_frame));
  
  frame->type = frstack_cleanup_jmp;
  frstack_add_frame(frame);

  ( (struct frstack_cleanup_jmp_frame *) frame)->target = NULL;
  return frame;
}


#ifdef FRAMESTACK_OBJC
frame_id
fr_cleanup_object(id object, SEL message)
{
  frame_id frame;
  struct frstack_cleanup_object_frame tmp;
  
  /* For error recovery in case obstack_alloc fails when allocating
   * another stack frame */
  the_frame_stack.tmp_frame = (frame_id) &tmp;
  tmp.link.type =  frstack_cleanup_object;
  tmp.rec = object;
  tmp.sel = message;

  frame = obstack_alloc(&(the_frame_stack.ob),
			sizeof(struct frstack_cleanup_object_frame));

  the_frame_stack.tmp_frame = NULL;
  
  frame->type = frstack_cleanup_object;
  frstack_add_frame(frame);

  ( (struct frstack_cleanup_object_frame *) frame)->rec = object;
  ( (struct frstack_cleanup_object_frame *) frame)->sel = message;
  return frame;
}

#endif FRAMESTACK_OBJC

/* This function may or may not return! If PLEASE_RETURN is non-zero,
 * or TARGET is NULL, cleanup actions involving LONGJMP() are not
 * performed, and the function returns to its caller.
 *
 * If TARGET is non-NULL, and PLEASE_RETURN is zero, all cleanup is
 * performed, and control is passed to the TARGET frame.
 */
void
frstack_unwind(frame_id target, int please_return)
{
  int stop;
  frame_id frame;

  /* No TARGET implies PLEASE_RETURN */
  if (!target)
    please_return = 1;
  
  /* First handle the case that memory allocation fails while a
   * unwind-protect function is being installed */
  if (the_frame_stack.tmp_frame)
    {
      frame = the_frame_stack.tmp_frame;
      the_frame_stack.tmp_frame = NULL;

      frstack_unwind_one_frame(frame, target, please_return);
    }  

  for (stop = 0, frame = the_frame_stack.last;
       frame && !stop;
       frame = frame->up)
    {
      if (frame == target)
	stop = 1;
      
      if (!frame->abandoned)
	frstack_unwind_one_frame(frame, target, please_return);
      
      /* Could perhaps free some frames here, but I don't, just
       * to try to keep things simple. Note, however, that the
       * cleanup function called may free some frames. */
    }
  if (target && !please_return)
    frstack_jmp(target);
  else
    /* Only in this case can we return to our caller. */
    if (please_return)
      return;
  /* What to do now? If this function is called with a NULL target,
   * for example from an at_exit handler, that should mean to
   * process all cleanup actions, and then return. But because of
   * cleanup actions of type cleanup_jmp, we may have LONGJMP() away
   * from this function and the LONGJMP() back. And in this case,
   * returning from this function will not send as back to the original
   * caller. It is even possible that the callers stackframe no
   * longer exists. */
  fprintf(stderr,"frstack_unwind: Don't know where to return.\n");
  abort();
}

void
frstack_unwind_one_frame(frame_id frame, frame_id target, int please_return)
{
  frame->abandoned = 1;
  switch (frame->type)
    {
    case frstack_none:
    case frstack_ccatch:

#ifdef FRAMESTACK_OBJC
    case frstack_catch_object:
#endif FRAMESTACK_OBJC
      ; /* Skip these frames */
      break;

    case frstack_cleanup_fn0:
      {
	struct frstack_cleanup_fn0_frame * fr;
	fr = (struct frstack_cleanup_fn0_frame *) frame;
	(fr->fn)();
      }
      break;
    case frstack_cleanup_fn1:
      {
	struct frstack_cleanup_fn1_frame * fr;
	fr = (struct frstack_cleanup_fn1_frame *) frame;

	(fr->fn)(fr->arg);
      }
      break;
    case frstack_cleanup_jmp:
      if (please_return)
	/* Can't LONGJMP() to cleanup routine, because then there's
	 * no way to return to the right place after unwinding. */
	;
      else
	{
	  struct frstack_cleanup_jmp_frame * fr;
	  fr = (struct frstack_cleanup_jmp_frame *) frame;

	  fr->target = target;

	  LONGJMP(fr->where, 17);
	  /* Does not return here. Cleanup routine is
	   * responsible for continuing the throw by
	   * calling frstack_continue. */
	  CANT_HAPPEN;
	}
      break;
#ifdef FRAMESTACK_OBJC
    case frstack_cleanup_object:
      {
	struct frstack_cleanup_object_frame * fr;
	fr = (struct frstack_cleanup_object_frame *) frame;
	[fr->rec perform: fr->sel];
      }
      break;
#endif FRAMESTACK_OBJC

    default:
      /* This is fatal. */
      fprintf(stderr, "frame_stack: Frame stack corrupt!"
	      "Unknown frame type %d\n",
	      frame->type);
      abort();
    }
}

void
frstack_continue(frame_id frame)
{
  frame_id target;

  target = ( (struct frstack_cleanup_jmp_frame *) frame)->target;
  if (target)
    {
      frstack_unwind(target, 0);
      CANT_HAPPEN;
    }
}

void
frstack_jmp(frame_id frame)
{
  switch(frame->type)
    {
    case frstack_ccatch:
      {
	struct frstack_ccatch_frame *fr;
	fr = (struct frstack_ccatch_frame *) frame;
	LONGJMP(fr->where, fr->value);
      }
      break;
#ifdef FRAMESTACK_OBJC
    case frstack_catch_object:
      {
	struct frstack_catch_object_frame *fr;
	fr = (struct frstack_catch_object_frame *) frame;
	[fr->object jump];
      }
      break;
#endif FRAMESTACK_OBJC
    default:
      /* Fatal */
      fprintf(stderr, "frstack_jmp: Can't jump to frame of type %d\n",
	      frame->type);
      abort();
      break;
    }
}

frame_id
frstack_find_frame(int (*cmp)(frame_id f, void *d),
		   void *data)
{
  frame_id p;

  for (p = the_frame_stack.last;
       p && (p->abandoned || !cmp(p, data));
       p = p->up)
    ;
  return p;
}

void
frstack_free(frame_id frame)
{
  if (frame)
    {
      the_frame_stack.last = frame->up;
      obstack_free(&(the_frame_stack.ob), frame);
    }
  else
    {
      the_frame_stack.last = NULL;
      obstack_free(&(the_frame_stack.ob), NULL);
      obstack_init(&(the_frame_stack.ob));
    }
}


static void *frame_stack_alloc(size_t size)
{
  void *p = malloc(size);
  if (p)
    return p;

  /* Handle out of memory */
  if (the_frame_stack.on_error)
    (*(the_frame_stack.on_error))();

  /* Out of memory, and no handler for it! */
  fprintf(stderr,"frame_stack: Out of memory\n");
  abort();
}

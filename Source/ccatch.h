/* ccatch.h
 *
 * C-interface to catch, throw and unwind-protect like facilities.
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */

#ifndef CCATCH_H_INCLUDED
#define CCATCH_H_INCLUDED

#include <frame_stack.h>

#define catch_tag frame_id
#define protect_tag frame_id

void
init_ccatch(void);

extern int
ccatch_cleanup_on_exit;

/* CCATCH
 *
 * Usage:
 *
 * catch_id tag;
 * if (CCATCH(tag,
 *            {
 *               body
 *            }))
 *    throw() lands here;
 * else
 *    no throw() happened;
 * ccatch_cleanup(tag);
 */

#define CCATCH(tag, body) ({ \
  (tag) = fr_ccatch_setup();\
  SETJMP(( (struct frstack_ccatch_frame *) (tag))->where) ? :((body), 0);\
})

#define ccatch_cleanup(tag) frstack_free(tag)

/* CTHROW
 *
 * Usage:
 *
 * CTHROW(tag, value);
 *
 * Passes control to the CCATCH that created the tag.
 */

#define CTHROW(tag, value) fr_cthrow((tag), (value))

/* CPROTECT
 *
 * Usage:
 *
 * CPROTECT(body, cleanup);
 *
 * CPROTECT({
 *             body
 *          },
 *          {
 *             cleanup
 *          });
 */

#define CPROTECT(body, cleanup) do {\
  protect_tag _CPROTECT_tag = fr_cleanup_jmp_setup(); \
  if (0 == SETJMP(( (struct frstack_cleanup_jmp_frame *) \
		    _CPROTECT_tag)->where)) \
    body \
  cleanup \
  frstack_continue(_CPROTECT_tag); \
  frstack_free(_CPROTECT_tag); \
} while (0)


#endif CCATCH_H_INCLUDED

/* ccatch.c
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */

#include <ccatch.h>
#include <stdio.h>
#include <stdlib.h>


int ccatch_cleanup_on_exit = 0;

static void
ccatch_on_exit(void)
{
  if (ccatch_cleanup_on_exit)
    {
      frstack_unwind(NULL, 1);
      frstack_free(NULL);
    }
}


void
init_ccatch(void)
{
  frstack_init();

  if (atexit(ccatch_on_exit) != 0)
    {
      fprintf(stderr, "init_catch: atexit() failed!\n");
      exit(EXIT_FAILURE);
    }
  ccatch_cleanup_on_exit = 1;
}

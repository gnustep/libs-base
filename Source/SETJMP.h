/* SETJMP.h
 *
 * That jmp_buf is declared as a typdefed array is a pain when trying
 * declare functions returning them.
 *
 * This is a work-around that encapsulates the jmp_buf in a struct.
 *
 * Copyright 1996 Niels Möller
 *
 * Written by: Niels Möller <nisse@lysator.liu.se>
 * Date: 1996
 *
 * Freely distributable under the terms and conditions of the
 * GNU Library General Public License.
 */

#ifndef JUMP_H_INCLUDED
#define JUMP_H_INCLUDED

#include <setjmp.h>

typedef struct { jmp_buf jmp; } _JMP_BUF;

#define JMP_BUF _JMP_BUF

#if DBUG

#define SETJMP(buf) \
({ \
   JMP_BUF *_buf = &(buf); \
   fprintf(stderr,"setjmp(%p)\n", _buf->jmp); \
   setjmp(_buf->jmp); \
})
     
#define LONGJMP(buf, value) \
({ \
   JMP_BUF *_buf = &(buf); \
   fprintf(stderr, "longjmp(%p, %d)\n", _buf->jmp, (value)); \
   longjmp(_buf->jmp, (value)); \
})
     
#else /* !DBUG */

#define SETJMP(buf) (setjmp((buf).jmp))
#define LONGJMP(buf, value) (longjmp((buf).jmp, (value)))

#endif /* !DBUG */
#endif JUMP_H_INCLUDED

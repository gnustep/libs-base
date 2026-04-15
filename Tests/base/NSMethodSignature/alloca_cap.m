/*
 * alloca_cap.m - regression test for NSMethodSignature type-string
 * buffer growth.
 *
 * -[NSMethodSignature _initWithObjCTypes:] rewrites the caller-supplied
 * type encoding into a temporary buffer sized proportionally to the
 * input length.  Before the cap was added, that buffer was always taken
 * from the stack via alloca, so a pathologically long type encoding
 * could force an arbitrarily large stack allocation and push past the
 * guard page.  The method now falls back to the heap for oversized
 * buffers while keeping the fast alloca path for ordinary signatures.
 *
 *   - ordinary short signatures still parse (alloca path).
 *   - signatures whose working buffer lands exactly at the cap still
 *     parse (last alloca-path case).
 *   - signatures whose working buffer lands just past the cap still
 *     parse (first heap-path case).
 *   - signatures whose working buffer would require more stack than
 *     is plausibly available still parse (deep heap path).  Without
 *     the cap this case would alloca a multi-megabyte buffer and
 *     crash the test process on any system with a normal stack limit.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

/* Build a valid Objective-C type encoding with `nargs` int arguments:
 * "v@:" followed by `nargs` copies of 'i'.  The returned pointer is
 * owned by the caller (and is deliberately leaked, because
 * +signatureWithObjCTypes: caches the pointer without copying it).
 */
static const char *
makeIntArgTypes(unsigned nargs)
{
  size_t	len = 3 + nargs;
  char		*buf = malloc(len + 1);
  unsigned	i;

  buf[0] = 'v';
  buf[1] = '@';
  buf[2] = ':';
  for (i = 0; i < nargs; i++)
    {
      buf[3 + i] = 'i';
    }
  buf[len] = '\0';
  return buf;
}

int
main(int argc, char *argv[])
{
  START_SET("NSMethodSignature alloca cap")
  NSMethodSignature	*sig;
  const char		*types;

  /* Sanity: a short signature still parses through the alloca path. */
  sig = [NSMethodSignature signatureWithObjCTypes: "v@:"];
  PASS(sig != nil, "short signature (v@:) parsed")

  /* Internal working buffer is (strlen+1)*16.  With blen <= 4096 the
   * alloca path is taken; 255 int args => strlen 258 => blen 4144, so
   * 254 int args => strlen 257 => blen 4128 — still over 4096.  Use
   * 252 int args => strlen 255 => blen 4096 to land exactly at the cap.
   */
  types = makeIntArgTypes(252);
  sig = [NSMethodSignature signatureWithObjCTypes: types];
  PASS(sig != nil, "252-arg signature at alloca cap parsed")

  /* One more argument tips the buffer over the cap and onto the heap. */
  types = makeIntArgTypes(253);
  sig = [NSMethodSignature signatureWithObjCTypes: types];
  PASS(sig != nil, "253-arg signature just past alloca cap parsed")

  /* A signature whose working buffer would require ~24 MB of stack
   * space — well past any reasonable stack limit (Linux defaults to
   * 8 MB).  Without the cap, +signatureWithObjCTypes: would alloca
   * that buffer and the process would die on the stack guard page
   * before returning.  With the cap, the buffer is heap-allocated
   * and the signature is built normally.
   */
  types = makeIntArgTypes(1500000);
  sig = [NSMethodSignature signatureWithObjCTypes: types];
  PASS(sig != nil, "1.5M-arg signature used heap buffer instead of stack")

  END_SET("NSMethodSignature alloca cap")
  return 0;
}

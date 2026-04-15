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

  /* -numberOfArguments counts self + _cmd + user arguments, so
   * "v@:" with N trailing 'i' produces (2 + N) arguments.  Each
   * case below checks both that the call returned a signature and
   * that the parser walked the whole type string.
   */

  /* Sanity: a short signature still parses through the alloca path. */
  sig = [NSMethodSignature signatureWithObjCTypes: "v@:"];
  PASS(sig != nil && [sig numberOfArguments] == 2,
    "short signature (v@:) parsed, 2 arguments")

  /* Internal working buffer is (strlen+1)*16.  With blen <= 4096 the
   * alloca path is taken; 252 int args gives strlen 255 and blen
   * exactly 4096, the last case on the alloca path.
   */
  types = makeIntArgTypes(252);
  sig = [NSMethodSignature signatureWithObjCTypes: types];
  PASS(sig != nil && [sig numberOfArguments] == 254,
    "252-arg signature at alloca cap parsed, 254 arguments")

  /* One more argument tips the buffer over the cap and onto the heap. */
  types = makeIntArgTypes(253);
  sig = [NSMethodSignature signatureWithObjCTypes: types];
  PASS(sig != nil && [sig numberOfArguments] == 255,
    "253-arg signature just past alloca cap parsed, 255 arguments")

  /* A signature whose working buffer would require ~24 MB of stack
   * space — well past any reasonable stack limit (Linux defaults to
   * 8 MB).  Without the cap, +signatureWithObjCTypes: would alloca
   * that buffer and the process would die on the stack guard page
   * before returning.  With the cap, the buffer is heap-allocated
   * and the signature is built normally.
   */
  types = makeIntArgTypes(1500000);
  sig = [NSMethodSignature signatureWithObjCTypes: types];
  PASS(sig != nil && [sig numberOfArguments] == 1500002,
    "1.5M-arg signature used heap path, 1500002 arguments")

  END_SET("NSMethodSignature alloca cap")
  return 0;
}

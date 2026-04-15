/*
 * alloca_cap.m - regression test for the type-string length cap in
 * -[NSMethodSignature _initWithObjCTypes:].
 *
 * The initialiser rewrites the caller-supplied type encoding into a
 * temporary buffer sized (strlen+1)*16 and takes that buffer from the
 * stack via alloca.  With no cap a pathologically long type encoding
 * could force an arbitrarily large stack allocation and push past the
 * guard page, so the initialiser now rejects any encoding whose
 * working buffer would exceed 4096 bytes (roughly strlen 255) with an
 * NSInvalidArgumentException.  No compiler-emitted method type
 * encoding comes anywhere near that length, so legitimate callers see
 * no change.
 *
 *   - ordinary short signatures still parse.
 *   - signatures whose working buffer lands exactly at the cap still
 *     parse (boundary case).
 *   - signatures one argument past the cap raise
 *     NSInvalidArgumentException.
 *   - signatures whose working buffer would exceed any reasonable
 *     stack limit also raise NSInvalidArgumentException rather than
 *     crashing the process.
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
   * "v@:" with N trailing 'i' produces (2 + N) arguments.  The
   * working buffer used by _initWithObjCTypes: is (strlen+1)*16,
   * so 252 int args gives strlen 255 and blen exactly 4096 (the
   * boundary), and 253 int args tips blen to 4112 (just past).
   */

  sig = [NSMethodSignature signatureWithObjCTypes: "v@:"];
  PASS(sig != nil && [sig numberOfArguments] == 2,
    "short signature (v@:) parsed, 2 arguments")

  types = makeIntArgTypes(252);
  sig = [NSMethodSignature signatureWithObjCTypes: types];
  PASS(sig != nil && [sig numberOfArguments] == 254,
    "252-arg signature at 4096-byte boundary parsed, 254 arguments")

  types = makeIntArgTypes(253);
  PASS_EXCEPTION(([NSMethodSignature signatureWithObjCTypes: types]),
    NSInvalidArgumentException,
    "253-arg signature one past boundary rejected")

  /* A signature whose working buffer would otherwise require ~24 MB
   * of stack — well past any reasonable stack limit — must also be
   * rejected, not crash the process.
   */
  types = makeIntArgTypes(1500000);
  PASS_EXCEPTION(([NSMethodSignature signatureWithObjCTypes: types]),
    NSInvalidArgumentException,
    "1.5M-arg signature rejected instead of crashing on alloca")

  END_SET("NSMethodSignature alloca cap")
  return 0;
}

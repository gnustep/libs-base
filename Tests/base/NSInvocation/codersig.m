/*
 * codersig.m - regression test for -[NSInvocation initWithCoder:].
 *
 * -initWithCoder: decoded the method-type string, built a method signature
 * from it, and replaced self with +invocationWithMethodSignature:.  When the
 * type string was missing or unparseable the signature (and hence the
 * invocation) was nil, but the method went on to decode the target/selector
 * and arguments "through" ivars off the nil self - a near-NULL out-of-bounds
 * write.  A nil signature is now rejected.
 */

#import <Foundation/Foundation.h>
#import "Testing.h"

/* Minimal coder that feeds an empty method-type string to -initWithCoder:. */
@interface BadSigCoder : NSCoder
@end

@implementation BadSigCoder
- (void) decodeValueOfObjCType: (const char*)type at: (void*)data
{
  if (type[0] == '*')		/* @encode(char*): the method type string */
    {
      /* empty string, NSZoneMalloc'd so -initWithCoder: can NSZoneFree it */
      char	*s = NSZoneMalloc(NSDefaultMallocZone(), 1);

      s[0] = '\0';
      *(char**)data = s;
    }
  else
    {
      *(void**)data = 0;
    }
}
@end

int
main(int argc, char *argv[])
{
  START_SET("NSInvocation initWithCoder bad signature")
  BadSigCoder	*c = [BadSigCoder new];

  PASS_EXCEPTION(
    [[NSInvocation alloc] initWithCoder: c],
    NSInvalidArgumentException,
    "an invalid method type string in an archive is rejected, not decoded through a nil invocation")

  RELEASE(c);
  END_SET("NSInvocation initWithCoder bad signature")

  return 0;
}

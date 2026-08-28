/*
 * codervla.m - regression test for -[NSValue initWithCoder:].
 *
 * In the (default, version >= 2) decode path, when the value's unpacked type
 * size was <= 64 the method placed the serialized bytes in a stack VLA
 * `unsigned char serialized[size]' whose length came straight from the
 * (untrusted) archive.  A large size therefore overran the stack.  The
 * serialized buffer is now heap allocated, as the > 64 case already was.
 *
 * The test drives -initWithCoder: with a minimal coder that supplies a small
 * "c" (char) object type and then an enormous serialized size.  Unpatched this
 * blows the stack; patched the (large but heap) buffer is handled cleanly.
 */

#import <Foundation/Foundation.h>
#import "Testing.h"

/* 64 MB: far larger than any thread stack, but a trivial heap allocation. */
#define HUGE_SIZE (64u * 1024u * 1024u)

@interface VLACoder : NSCoder
{
  int	unsignedCalls;
}
@end

@implementation VLACoder
- (void) decodeValueOfObjCType: (const char*)type at: (void*)data
{
  if (strcmp(type, @encode(unsigned)) == 0)
    {
      /* First unsigned decoded is the length of the object-type string;
       * the second is the serialized-buffer size (the attack value). */
      if (unsignedCalls++ == 0)
	{
	  *(unsigned*)data = 2;
	}
      else
	{
	  *(unsigned*)data = HUGE_SIZE;
	}
    }
}
- (void) decodeArrayOfObjCType: (const char*)type
			 count: (NSUInteger)count
			    at: (void*)data
{
  /* The object-type string: a plain char value ("c"); valueClassWithObjCType:
   * maps this to the generic concrete value class, which is what reaches the
   * serialized-buffer branch. */
  if (strcmp(type, @encode(signed char)) == 0 && count >= 2)
    {
      char	*p = (char*)data;

      p[0] = 'c';
      p[1] = '\0';
    }
  /* @encode(unsigned char): the serialized payload - left untouched. */
}
- (NSInteger) versionForClassName: (NSString*)className
{
  return 3;
}
- (NSZone*) objectZone
{
  return NSDefaultMallocZone();
}
@end

int
main(int argc, char *argv[])
{
  START_SET("NSValue initWithCoder serialized size")
  VLACoder	*c = [VLACoder new];
  NSValue	*v;

  v = [[NSValue alloc] initWithCoder: c];
  PASS(v != nil,
    "decoding an NSValue with a large serialized size does not overflow the stack")

  RELEASE(v);
  RELEASE(c);
  END_SET("NSValue initWithCoder serialized size")

  return 0;
}

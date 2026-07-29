/*
 * coderinfo.m - regression test for -[NSAttributedString initWithCoder:].
 *
 * The keyed-decoding path unpacks per-attribute-run lengths and indices from
 * the NSAttributeInfo data as a sequence of variable-length integers.  The
 * inner decode loops `while (*p & 0x80)' (and the following `*p++') had no
 * `p < end' bound, so an NSAttributeInfo value ending in a continuation byte
 * (high bit set) read past the end of the buffer.  The loops are now bounded.
 *
 * To make the over-read observable rather than silently reading adjacent heap,
 * the single 0x80 byte is placed at the very end of a page whose successor
 * page is unmapped, so any read past it faults.  (Unix only; on other
 * platforms the test is skipped.)
 */

#import <Foundation/Foundation.h>
#import "Testing.h"

#if defined(__unix__) || defined(__APPLE__)
#include <sys/mman.h>
#include <unistd.h>
#define HAVE_GUARD_PAGE 1
#endif

/* Minimal keyed coder supplying just the keys -initWithCoder: reads. */
@interface InfoCoder : NSCoder
{
@public
  NSData	*info;
}
@end

@implementation InfoCoder
- (BOOL) allowsKeyedCoding			{ return YES; }
- (BOOL) containsValueForKey: (NSString*)k	{ return YES; }
- (id) decodeObjectForKey: (NSString*)k
{
  if ([k isEqual: @"NSString"])
    {
      return @"AB";
    }
  if ([k isEqual: @"NSAttributeInfo"])
    {
      return info;
    }
  if ([k isEqual: @"NSAttributes"])
    {
      return [NSArray arrayWithObject: [NSDictionary dictionary]];
    }
  return nil;
}
@end

int
main(int argc, char *argv[])
{
  START_SET("NSAttributedString NSAttributeInfo over-read")
#if HAVE_GUARD_PAGE
  long		pg = sysconf(_SC_PAGESIZE);
  unsigned char	*base;

  base = mmap(NULL, 2 * pg, PROT_READ | PROT_WRITE,
    MAP_PRIVATE | MAP_ANON, -1, 0);
  if (base == MAP_FAILED)
    {
      SKIP("could not mmap a guard page")
    }
  else
    {
      InfoCoder		*c;
      NSAttributedString	*s;
      unsigned char	*infoByte = base + pg - 1;

      /* Make the second page inaccessible; put a lone continuation byte at the
       * last accessible byte so a read past it hits the guard page. */
      mprotect(base + pg, pg, PROT_NONE);
      *infoByte = 0x80;

      c = [InfoCoder new];
      c->info = [NSData dataWithBytesNoCopy: infoByte length: 1 freeWhenDone: NO];

      s = [[NSAttributedString alloc] initWithCoder: c];
      PASS(s != nil,
	"decoding NSAttributeInfo that ends in a continuation byte does not read past the buffer")

      RELEASE(s);
      RELEASE(c);
      munmap(base, 2 * pg);
    }
#else
  SKIP("guard-page mechanism is Unix only")
#endif
  END_SET("NSAttributedString NSAttributeInfo over-read")

  return 0;
}

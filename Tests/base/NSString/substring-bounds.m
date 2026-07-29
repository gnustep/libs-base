/*
 * substring-bounds.m - regression test for the GSCString substring range
 * check.
 *
 * -[GSCString substringFromRange:] and -[GSCString substringWithRange:]
 * ran the "tiny string" fast path - createTinyString((char*)_contents.c
 * + aRange.location, aRange.length) - before validating aRange against
 * the receiver's length.  createTinyString reads up to 9 bytes from that
 * pointer, so an out-of-range range read past the end of the character
 * buffer.  The GS_RANGE_CHECK is now performed first, matching the
 * GSMutableString implementations.
 *
 * To make the over-read observable rather than silently reading adjacent
 * heap, the string bytes are placed at the very end of a page whose
 * successor page is unmapped, so any read past them faults.  (Unix only;
 * elsewhere the guard-page part is skipped.)
 */

#import <Foundation/Foundation.h>
#import "Testing.h"

#if defined(__unix__) || defined(__APPLE__)
#include <sys/mman.h>
#include <unistd.h>
#include <string.h>
#define HAVE_GUARD_PAGE 1
#endif

int
main(int argc, char *argv[])
{
  START_SET("GSCString substring range check")

  /* Positive control: in-range substrings of a non-owned C-string still
   * work (a non-owned, non-wide GSCString is what exercises the tiny
   * fast path).
   */
  {
    char	bytes[] = "hello world";
    NSString	*s = [[NSString alloc] initWithBytesNoCopy: bytes
						       length: 11
						     encoding: NSISOLatin1StringEncoding
						 freeWhenDone: NO];

    PASS_EQUAL([s substringWithRange: NSMakeRange(0, 5)], @"hello",
      "in-range -substringWithRange: returns the substring")
    PASS_EQUAL([s substringFromRange: NSMakeRange(6, 5)], @"world",
      "in-range -substringFromRange: returns the substring")
    RELEASE(s);
  }

#if HAVE_GUARD_PAGE
  {
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
	unsigned	len = 16;	/* > 9 so the receiver is a heap GSCString */
	unsigned char	*p = base + pg - len;	/* bytes end at the page edge */
	NSString	*s;

	mprotect(base + pg, pg, PROT_NONE);
	memcpy(p, "0123456789abcdef", len);
	s = [[NSString alloc] initWithBytesNoCopy: p
					   length: len
					 encoding: NSISOLatin1StringEncoding
				     freeWhenDone: NO];

	/* An out-of-range length: the tiny-string fast path would read up
	 * to 9 bytes from _contents.c + location, past the page edge and
	 * into the guard page.  The range check must reject it first.
	 */
	PASS_EXCEPTION([s substringWithRange: NSMakeRange(10, 9)],
	  NSRangeException,
	  "-substringWithRange: range-checks before the tiny-string fast path")
	PASS_EXCEPTION([s substringFromRange: NSMakeRange(10, 9)],
	  NSRangeException,
	  "-substringFromRange: range-checks before the tiny-string fast path")

	RELEASE(s);
	munmap(base, 2 * pg);
      }
  }
#else
  SKIP("guard-page mechanism is Unix only")
#endif

  END_SET("GSCString substring range check")

  return 0;
}

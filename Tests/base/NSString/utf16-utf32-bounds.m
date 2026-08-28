#import "ObjectTesting.h"
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>

#if	defined(__unix__) || defined(__APPLE__)
#include <sys/mman.h>
#include <unistd.h>
#include <string.h>

/* Decode `n` bytes that sit at the very end of a page whose following page is
 * unmapped, so an over-read past the data faults instead of silently reading
 * adjacent memory. */
static NSString *
guarded(NSUInteger n, NSStringEncoding enc)
{
  long		pg = sysconf(_SC_PAGESIZE);
  char		*base = mmap(NULL, 2 * pg, PROT_READ | PROT_WRITE,
    MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  char		*p;
  NSString	*s;

  if (base == MAP_FAILED) return nil;
  p = base + pg - n;
  memset(p, 'A', n);
  mprotect(base + pg, pg, PROT_NONE);
  s = [[NSString alloc] initWithData:
    [NSData dataWithBytesNoCopy: p length: n freeWhenDone: NO] encoding: enc];
  mprotect(base + pg, pg, PROT_READ | PROT_WRITE);
  munmap(base, 2 * pg);
  return [s autorelease];
}
#endif

int main()
{
  START_SET("NSString UTF-16/UTF-32 data length bounds")

  /* A well-formed UTF-16 buffer still decodes correctly. */
  {
    unsigned char	bytes[] = { 0x00, 'A', 0x00, 'B' };	/* "AB" BE */
    NSString		*s = [[[NSString alloc] initWithData:
      [NSData dataWithBytes: bytes length: 4]
      encoding: NSUTF16BigEndianStringEncoding] autorelease];

    PASS_EQUAL(s, @"AB", "a well-formed UTF-16 buffer decodes")
  }

#if	defined(__unix__) || defined(__APPLE__)
  /* The UTF-16 and UTF-32 decoders read a whole 2- or 4-byte unit each
   * iteration but only checked that a single byte remained, over-reading a
   * buffer whose length is not a multiple of the unit size.  Reaching here
   * (rather than faulting on the guard page) is the regression check. */
  PASS(guarded(1, NSUTF16BigEndianStringEncoding) != nil,
    "an odd-length UTF-16 buffer is decoded without over-reading")
  PASS(guarded(3, NSUTF32BigEndianStringEncoding) != nil,
    "a non-multiple-of-4 UTF-32 buffer is decoded without over-reading")
#endif

  END_SET("NSString UTF-16/UTF-32 data length bounds")
  return 0;
}

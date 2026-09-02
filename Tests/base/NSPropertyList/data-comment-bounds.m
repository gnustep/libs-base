#import "ObjectTesting.h"
#import <Foundation/NSData.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSString.h>

#if defined(__unix__) || defined(__APPLE__)
#include <sys/mman.h>
#include <unistd.h>
#include <string.h>
#endif

int main()
{
  START_SET("NSPropertyList data comment over-read")

  /* A well-formed <hex> data value still parses. */
  {
    NSData	*good = [@"<4142>" dataUsingEncoding: NSUTF8StringEncoding];
    NSData	*expect = [NSData dataWithBytes: "AB" length: 2];
    id		pl = [NSPropertyListSerialization propertyListWithData: good
      options: 0 format: NULL error: NULL];

    PASS_EQUAL(pl, expect, "a well-formed <hex> data value parses")
  }

#if defined(__unix__) || defined(__APPLE__)
  /* While parsing <...> data, a '/' '*' comment can consume the closing '>'
   * and run the parser to the end of the buffer; the terminator check then
   * read one byte past the end.  Put the payload at the end of a page backed
   * by a PROT_NONE guard page so the over-read faults deterministically
   * instead of silently reading adjacent memory. */
  {
    static const char	payload[] = "<41/*>";
    long		pg = sysconf(_SC_PAGESIZE);
    char		*base = mmap(NULL, 2 * pg, PROT_READ | PROT_WRITE,
      MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);

    if (base == MAP_FAILED)
      {
	SKIP("could not mmap a guard page")
      }
    else
      {
	size_t	len = sizeof(payload) - 1;
	char	*p = base + pg - len;	/* payload ends at the page boundary */
	NSData	*d;
	id	pl;

	memcpy(p, payload, len);
	mprotect(base + pg, pg, PROT_NONE);	/* the byte after it faults */
	d = [NSData dataWithBytesNoCopy: p length: len freeWhenDone: NO];
	pl = [NSPropertyListSerialization propertyListWithData: d
	  options: 0 format: NULL error: NULL];

	PASS(pl == nil,
	  "a comment eating the data terminator is rejected, not over-read")

	mprotect(base + pg, pg, PROT_READ | PROT_WRITE);
	munmap(base, 2 * pg);
      }
  }
#endif

  END_SET("NSPropertyList data comment over-read")
  return 0;
}

#import <Foundation/NSArchiver.h>
#import <Foundation/NSData.h>
#import <Foundation/NSException.h>
#import <Foundation/NSAutoreleasePool.h>
#import "Testing.h"

/* A value archived as an integer must decode into a char destination.
   BOOL is a char on most platforms but an int with the libobjc2 runtime on
   Windows, so a gorm written there archives its BOOL values as ints and has
   to decode them into char slots everywhere else.  This is the reverse of the
   char to int widening in charWidening.m.  (gnustep/libs-gui#318) */

#define	ARCHIVE_AS(NAME, TYPE) \
static NSData * \
NAME (TYPE v) \
{ \
  NSMutableData *d = [NSMutableData data]; \
  NSArchiver *a = [[NSArchiver alloc] initForWritingWithMutableData: d]; \
  [a encodeValueOfObjCType: @encode(TYPE) at: &v]; \
  [a release]; \
  return d; \
}

ARCHIVE_AS(archiveUChar, unsigned char)
ARCHIVE_AS(archiveShort, short)
ARCHIVE_AS(archiveInt, int)
ARCHIVE_AS(archiveUInt, unsigned int)
ARCHIVE_AS(archiveLongLong, long long)

/* Decode data as type, returning whether it succeeded without an exception. */
static BOOL
decodeAs(NSData *data, const char *type, void *out)
{
  NSUnarchiver *u = [[NSUnarchiver alloc] initForReadingWithData: data];
  BOOL ok = YES;

  NS_DURING
    [u decodeValueOfObjCType: type at: out];
  NS_HANDLER
    ok = NO;
  NS_ENDHANDLER
  [u release];
  return ok;
}

int
main(void)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  char c = -1;
  signed char sc = -1;
  unsigned char uc = 1;
  int i = -1;

  PASS(decodeAs(archiveInt(1), @encode(char), &c) && c == 1,
    "an int archived as 1 decodes into a char as 1");
  PASS(decodeAs(archiveInt(0), @encode(char), &c) && c == 0,
    "an int archived as 0 decodes into a char as 0");
  PASS(decodeAs(archiveInt(1), @encode(unsigned char), &uc) && uc == 1,
    "an int archived as 1 decodes into an unsigned char as 1");
  PASS(decodeAs(archiveInt(-5), @encode(signed char), &sc) && sc == -5,
    "an int archived as -5 decodes into a signed char as -5");
  PASS(decodeAs(archiveUInt(200), @encode(unsigned char), &uc) && uc == 200,
    "an unsigned int archived as 200 decodes into an unsigned char as 200");
  PASS(decodeAs(archiveShort(7), @encode(char), &c) && c == 7,
    "a short archived as 7 decodes into a char as 7");
  PASS(decodeAs(archiveLongLong(1), @encode(char), &c) && c == 1,
    "a long long archived as 1 decodes into a char as 1");

  PASS(decodeAs(archiveInt(1234), @encode(int), &i) && i == 1234,
    "an int still decodes into an int unchanged");

  /* BOOL is a char in some builds and an int in others, so one of these two
     is a decode across widths whichever build this is. */
  {
    BOOL	b = NO;

    PASS(decodeAs(archiveInt(1), @encode(BOOL), &b) && b,
      "a BOOL archived as an int decodes as YES");
    b = NO;
    PASS(decodeAs(archiveUChar(1), @encode(BOOL), &b) && b,
      "a BOOL archived as an unsigned char decodes as YES");
  }

  {
    NSMutableData	*d = [NSMutableData data];
    NSArchiver		*a;
    NSUnarchiver	*u;
    int			ints[4] = { 0, 1, 127, -5 };
    unsigned int	uints[3] = { 0, 1, 200 };
    signed char		chars[4] = { 9, 9, 9, 9 };
    unsigned char	uchars[3] = { 9, 9, 9 };
    BOOL		ok = YES;

    a = [[NSArchiver alloc] initForWritingWithMutableData: d];
    [a encodeArrayOfObjCType: @encode(int) count: 4 at: ints];
    [a release];
    u = [[NSUnarchiver alloc] initForReadingWithData: d];
    NS_DURING
      [u decodeArrayOfObjCType: @encode(char) count: 4 at: chars];
    NS_HANDLER
      ok = NO;
    NS_ENDHANDLER
    [u release];
    PASS(ok && chars[0] == 0 && chars[1] == 1 && chars[2] == 127
      && chars[3] == -5, "an array of ints decodes into an array of chars");

    d = [NSMutableData data];
    a = [[NSArchiver alloc] initForWritingWithMutableData: d];
    [a encodeArrayOfObjCType: @encode(unsigned int) count: 3 at: uints];
    [a release];
    ok = YES;
    u = [[NSUnarchiver alloc] initForReadingWithData: d];
    NS_DURING
      [u decodeArrayOfObjCType: @encode(unsigned char) count: 3 at: uchars];
    NS_HANDLER
      ok = NO;
    NS_ENDHANDLER
    [u release];
    PASS(ok && uchars[0] == 0 && uchars[1] == 1 && uchars[2] == 200,
      "an array of unsigned ints decodes into an array of unsigned chars");
  }

  [arp release]; arp = nil;
  return 0;
}

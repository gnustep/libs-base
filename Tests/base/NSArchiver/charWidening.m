#import <Foundation/NSArchiver.h>
#import <Foundation/NSData.h>
#import <Foundation/NSException.h>
#import <Foundation/NSAutoreleasePool.h>
#import "Testing.h"

/* A value archived as a char must decode into a wider integer destination.
   BOOL is a char on most platforms but an int with the libobjc2 runtime on
   Windows, so a gorm (which encodes BOOL as unsigned char) has to decode its
   BOOL values into int slots there.  Before this was handled, the decode
   raised "expected int and got unsigned char".  (gnustep/libs-gui#318, #405) */

static NSData *
archiveUChar(unsigned char c)
{
  NSMutableData *d = [NSMutableData data];
  NSArchiver *a = [[NSArchiver alloc] initForWritingWithMutableData: d];
  [a encodeValueOfObjCType: @encode(unsigned char) at: &c];
  [a release];
  return d;
}

static NSData *
archiveSChar(signed char c)
{
  NSMutableData *d = [NSMutableData data];
  NSArchiver *a = [[NSArchiver alloc] initForWritingWithMutableData: d];
  [a encodeValueOfObjCType: @encode(signed char) at: &c];
  [a release];
  return d;
}

/* Decode data as an int, returning whether it succeeded without an exception. */
static BOOL
decodeAsInt(NSData *data, int *out)
{
  NSUnarchiver *u = [[NSUnarchiver alloc] initForReadingWithData: data];
  BOOL ok = YES;

  NS_DURING
    [u decodeValueOfObjCType: @encode(int) at: out];
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
  int i = -1;
  short s = -1;
  long l = -1;
  long long ll = -1;
  unsigned char uc = 0;
  NSUnarchiver *u;

  PASS(decodeAsInt(archiveUChar(1), &i) && i == 1,
    "an unsigned char archived as 1 decodes into an int as 1");
  PASS(decodeAsInt(archiveUChar(0), &i) && i == 0,
    "an unsigned char archived as 0 decodes into an int as 0");
  PASS(decodeAsInt(archiveUChar(255), &i) && i == 255,
    "an unsigned char archived as 255 decodes into an int as 255");

  PASS(decodeAsInt(archiveSChar(-5), &i) && i == -5,
    "a signed char archived as -5 decodes into an int as -5");
  PASS(decodeAsInt(archiveSChar(-128), &i) && i == -128,
    "a signed char archived as -128 decodes into an int as -128");

  u = [[NSUnarchiver alloc] initForReadingWithData: archiveUChar(200)];
  NS_DURING
    [u decodeValueOfObjCType: @encode(short) at: &s];
  NS_HANDLER
    s = -1;
  NS_ENDHANDLER
  [u release];
  PASS(s == 200, "an unsigned char decodes into a short");

  u = [[NSUnarchiver alloc] initForReadingWithData: archiveUChar(200)];
  NS_DURING
    [u decodeValueOfObjCType: @encode(long) at: &l];
  NS_HANDLER
    l = -1;
  NS_ENDHANDLER
  [u release];
  PASS(l == 200, "an unsigned char decodes into a long");

  u = [[NSUnarchiver alloc] initForReadingWithData: archiveUChar(200)];
  NS_DURING
    [u decodeValueOfObjCType: @encode(long long) at: &ll];
  NS_HANDLER
    ll = -1;
  NS_ENDHANDLER
  [u release];
  PASS(ll == 200, "an unsigned char decodes into a long long");

  u = [[NSUnarchiver alloc] initForReadingWithData: archiveUChar(42)];
  NS_DURING
    [u decodeValueOfObjCType: @encode(unsigned char) at: &uc];
  NS_HANDLER
    uc = 0;
  NS_ENDHANDLER
  [u release];
  PASS(uc == 42, "an unsigned char still decodes into an unsigned char unchanged");

  [arp release]; arp = nil;
  return 0;
}

/* A demonstration of writing and reading GNU Objective C objects to a file. */

#include <objects/BinaryCStream.h>
#include <objects/Array.h>
#include <objects/Dictionary.h>
#include <objects/NSString.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSValue.h>

int main(int argc, char *argv[])
{
  id arp;
  long l = 0x6543;
  int i = 0x1234;
  unsigned u = 2;
  short s = 0x987;
  char c = 0x12;
  char *string = "Testing";
  float f = 0.1234;
  double d = 0.987654321;
  id cstream;
  Class cstream_class;
  
  if (argc > 1)
    cstream_class = objc_get_class (argv[1]);
  else
    cstream_class = [BinaryCStream class];

  [NSObject enableDoubleReleaseCheck: YES];
  arp = [[NSAutoreleasePool alloc] init];

  cstream = [[cstream_class alloc]
	      initForWritingToFile: @"cstream.dat"];

  /* Write an integer to a file */
  [cstream encodeWithName: @"some values"
	   valuesOfCTypes: "liIsc*fd",
	   &l, &i, &u, &s, &c, &string, &f, &d];
  printf ("Wrote %d %d %u %d %d %s %g %g\n",
	  (int)l, i, u, (int)s, (int)c, string, f, d);
  [[cstream stream] close];

  cstream = [cstream_class cStreamReadingFromFile: @"cstream.dat"];
  [cstream decodeWithName: NULL
	   valuesOfCTypes: "liIsc*",
	   &l, &i, &u, &s, &c, &string, &f, &d];
  printf ("Read  %d %d %u %d %d %s %g %g\n",
	  (int)l, i, u, (int)s, (int)c, string, f, d);
  [[cstream stream] close];

  /* Do the autorelease. */
  [arp release];
  
  exit(0);
}

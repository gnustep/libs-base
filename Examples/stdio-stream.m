/* A simple example of writing and reading to a file using the 
   GNU StdioStream object. */

#include <gnustep/base/StdioStream.h>
#include <Foundation/NSString.h>

int main()
{
  id stream;
  int count = 0;
  int i = 0;
  float f = 0.0;
  double d = 0.0;
  unsigned u = 0;
  unsigned char uc = 0;
  unsigned ux = 0;
  char *cp = NULL;

  stream = [[StdioStream alloc] 
	    initWithFilename: @"./stdio-stream.txt"
	    fmode:"w"];
  [stream writeFormat: @"testing %d %u %f %f 0x%x \"cow\"\n", 
	  1234, 55, 3.14159, 1.23456789, 0xfeedface];
  [stream release];

  stream = [[StdioStream alloc] 
	    initWithFilename: @"./stdio-stream.txt"
	    fmode:"r"];
  count = [stream readFormat: @"testing %d %u %f %lf 0x%x \"%a[^\"]\"\n", 
	  &i, &u, &f, &d, &ux, &cp];
  uc = (unsigned char) ux;
  [stream release];
  printf("Read count=%d, int=%d unsigned=%u float=%f double=%f "
	 "uchar=0x%x char*=%s\n", 
	 count, i, u, f, d, (unsigned)uc, cp);

  exit(0);
}

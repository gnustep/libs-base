#include <objects/TextCoder.h>
#include <objects/StdioStream.h>
#include <objects/Set.h>
#include <objects/EltNodeCollector.h>
#include <objects/LinkedList.h>
#include <objects/LinkedListEltNode.h>

int main()
{
#if 0
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
	    initWithFilename:"./textcoding.txt"
	    fmode:"w"];
  [stream writeFormat:"testing %d %u %f %f 0x%x \"cow\"\n", 
	  1234, 55, 3.14159, 1.23456789, 0xfeedface];
  [stream release];

  stream = [[StdioStream alloc] 
	    initWithFilename:"./textcoding.txt"
	    fmode:"r"];
  count = [stream readFormat:"testing %d %u %f %lf 0x%x \"%a[^\"]\"\n", 
	  &i, &u, &f, &d, &ux, &cp];
  uc = (unsigned char) ux;
  [stream release];
  printf("Read count=%d, int %d unsigned %u float %f double %f "
	 "uchar %x cp %s\n", 
	 count, i, u, f, d, (unsigned)uc, cp);

#else
  id set, ll;
  id stream;
  id coder;
  const char *n;

  set = [[Set alloc] initWithType:@encode(int)];
  ll = [[EltNodeCollector alloc] initWithType:@encode(float)
	nodeCollector:[[LinkedList alloc] init]
	nodeClass:[LinkedListEltNode class]];

  [set addElement:1];
  [set addElement:2];
  [set addElement:3];
  [set addElement:4];
  [set addElement:5];
  [set printForDebugger];

  [ll addElement:(float)1.2];
  [ll addElement:(float)3.4];
  [ll addElement:(float)5.6];
  [ll addElement:(float)7.8];
  [ll addElement:(float)9.0];
  [ll printForDebugger];

  stream = [[StdioStream alloc] 
	    initWithFilename:"./textcoding.txt"
	    fmode:"w"];
  coder = [[TextCoder alloc] initEncodingOnStream:stream];
  [coder encodeObject:set withName:"Test Set"];
  [coder encodeObject:ll withName:"Test EltNodeCollector LinkedList"];
  [coder release];
  [set release];
  [ll release];

  stream = [[StdioStream alloc] 
	    initWithFilename:"./textcoding.txt"
	    fmode:"r"];
  coder = [[TextCoder alloc] initDecodingOnStream:stream];
  [coder decodeObjectAt:&set withName:&n];
  printf("got object named %s\n", n);
  (*objc_free)((void*)n);
  [coder decodeObjectAt:&ll withName:&n];
  printf("got object named %s\n", n);
  (*objc_free)((void*)n);
  [set printForDebugger];
  [ll printForDebugger];
  [coder release];
  [set release];
  [ll release];
#endif
  
  exit(0);
}

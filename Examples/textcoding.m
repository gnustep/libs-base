/* A demonstration of writing and reading GNU Objective C objects to a file,
   in human-readable text format.
   Look at the file "textcoding.txt" after running this program to see the
   text archive format.
   */

#include <objects/TextCoder.h>
#include <objects/StdioStream.h>
#include <objects/Set.h>
#include <objects/EltNodeCollector.h>
#include <objects/LinkedList.h>
#include <objects/LinkedListEltNode.h>

int main()
{
  id set, ll;
  id stream;
  id coder;
  const char *n;

  /* Create a Set of int's
     and a LinkedList of float's */
  set = [[Set alloc] initWithType:@encode(int)];
  ll = [[EltNodeCollector alloc] initWithType:@encode(float)
	nodeCollector:[[LinkedList alloc] init]
	nodeClass:[LinkedListEltNode class]];

  /* Populate the Set and display it */
  [set addElement:1234567];
  [set addElement:2345678];
  [set addElement:3456789];
  [set addElement:4567891];
  [set addElement:5678912];
  [set printForDebugger];

  /* Populate the LinkedList and display it */
  [ll addElement:1.2f];
  [ll addElement:(float)3.4];
  [ll addElement:(float)5.6];
  [ll addElement:(float)7.8];
  [ll addElement:(float)9.0];
  [ll printForDebugger];

  /* Write them to a file */
  stream = [[StdioStream alloc] 
	    initWithFilename:"./textcoding.txt"
	    fmode:"w"];
  coder = [[TextCoder alloc] initEncodingOnStream:stream];
  [coder encodeObject:set withName:"Test Set"];
  [coder encodeObject:ll withName:"Test EltNodeCollector LinkedList"];

  /* Free the objects */
  [coder release];
  [set release];
  [ll release];

  /* Read them back in from the file */
  /* First init the stream and coder */
  stream = [[StdioStream alloc] 
	    initWithFilename:"./textcoding.txt"
	    fmode:"r"];
  coder = [[TextCoder alloc] initDecodingOnStream:stream];

  /* Read in the Set */
  [coder decodeObjectAt:&set withName:&n];
  printf("got object named %s\n", n);
  /* The name was malloc'ed by the Stream, free it */
  (*objc_free)((void*)n);

  /* Read in the LinkedList */
  [coder decodeObjectAt:&ll withName:&n];
  printf("got object named %s\n", n);
  /* The name was malloc'ed by the Stream, free it */
  (*objc_free)((void*)n);

  /* Display what we read, to make sure it matches what we wrote */
  [set printForDebugger];
  [ll printForDebugger];

  /* Free the objects */
  [coder release];
  [set release];
  [ll release];
  
  exit(0);
}

/* Some notes:

   This program is a great example of how allocating and freeing
   memory is very screwed up:

   * The Stream allocates the name, we have to free it.

   * The Coder free's its Stream when the Coder is free'd, but we
   were the ones to create it.

   These difficult and ad-hoc rules will be fixed in the future.

*/

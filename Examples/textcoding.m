/* A demonstration of writing and reading GNU Objective C objects to a file,
   in human-readable text format.
   Look at the file "textcoding.txt" after running this program to see the
   text archive format.
   */

#include <gnustep/base/Archiver.h>
#include <gnustep/base/TextCStream.h>
#include <gnustep/base/Array.h>
#include <gnustep/base/Dictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSValue.h>

int main()
{
  id array, dictionary;
  id archiver;
  id name;
  id arp;
  int i;

  [NSObject enableDoubleReleaseCheck: YES];
  arp = [[NSAutoreleasePool alloc] init];

  /* Create an Array and Dictionary */
  array = [Array new];
  dictionary = [Dictionary new];

  for (i = 0; i < 6; i++)
    {
      [array addObject: [NSNumber numberWithInt: i]];
      [dictionary putObject: [NSNumber numberWithInt: i] 
		  atKey: [NSNumber numberWithInt: i*i]];
    }
  [array printForDebugger];
  [dictionary printForDebugger];

  /* Write them to a file */

  /* Create an instances of the Archiver class, specify that we 
     want human-readable "Text"-style, instead of "Binary"-style
     coding. */
  archiver = [[Archiver alloc] initForWritingToFile: @"./textcoding.txt"
			       withCStreamClass: [TextCStream class]];
  [archiver encodeObject: array 
	    withName: @"Test Array"];
  [archiver encodeObject: dictionary
	    withName: @"Test Dictionary"];

  /* Release the objects that were coded */
  [array release];
  [dictionary release];

  /* Close the archiver, (and thus flush the stream); then release it.
     We must separate the idea of "closing" a stream and
     "deallocating" a stream because of delays in deallocation due to
     -autorelease. */
  [archiver close];
  [archiver release];


  /* Read them back in from the file */

  /* First create the unarchiver */
  archiver = [Unarchiver newReadingFromFile: @"./textcoding.txt"];

  /* Read in the Array */
  [archiver decodeObjectAt: &array withName: &name];
  printf("got object named %@\n", name);

  /* Read in the Dictionary */
  [archiver decodeObjectAt: &dictionary withName: &name];
  printf("got object named %@\n", name);

  /* Display what we read, to make sure it matches what we wrote */
  [array printForDebugger];
  [dictionary printForDebugger];

  /* Release the objects we read */
  [array release];
  [dictionary release];

  /* Release the unarchiver. */
  [archiver release];

  /* Do the autorelease. */
  [arp release];
  
  exit(0);
}

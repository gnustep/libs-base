/* A demonstration of writing and reading with NSArchiver */

#if 1

#include <Foundation/NSArchiver.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSDate.h>

int main()
{
  id set;
  id arp;
  id arc;
  id una;
  id xxx;
  id apl;
  
  [NSAutoreleasePool enableDoubleReleaseCheck:YES];
  
  arp = [[NSAutoreleasePool alloc] init];

  /* Create a Set of int's */
  set = [[NSSet alloc] initWithObjects:
	  @"apple", @"banana", @"carrot", @"dal", @"escarole", @"fava", nil];

  /* Display the set */
  printf("Writing:\n");
  {
    id o, e = [set objectEnumerator];
    while ((o = [e nextObject]))
      printf("%s\n", [o cString]);    
  }

  apl = [[NSAutoreleasePool alloc] init];
  arc = [[NSArchiver new] autorelease];
printf("%u\n", [arc retainCount]);
  [arc retain];
printf("%u\n", [arc retainCount]);
  [arc release];
printf("%u\n", [arc retainCount]);
  [arc encodeRootObject: set];
  una = [[[NSUnarchiver alloc] initForReadingWithData: [arc archiverData]] autorelease];
  xxx = [una decodeObject];
  if ([xxx isEqual: set] == NO)
    printf("Argh\n");
  printf("%s\n", [[xxx description] cString]);
  [apl release];


  /* Write it to a file */
  [NSArchiver archiveRootObject: set toFile: @"./nsarchiver.dat"];

  /* Release the object that was coded */
  [set release];

  /* Read it back in from the file */
#if 1
  {
    id d = [[NSData alloc] initWithContentsOfFile:@"./nsarchiver.dat"];
    id a = [NSUnarchiver alloc];
    a = [a initForReadingWithData:d];
    set = [a decodeObject];
  }
#else
  set = [NSUnarchiver unarchiveObjectWithFile: @"./nsarchiver.dat"];
#endif

  /* Display what we read, to make sure it matches what we wrote */
  printf("\nReading:\n");
  {
    id o, e = [set objectEnumerator];
    while ((o = [e nextObject]))
      printf("%s\n", [o cString]);    
  }

  {
    NSDate		*start = [NSDate date];
    NSAutoreleasePool	*arp = [NSAutoreleasePool new];
    int			i;
    NSUnarchiver	*u = nil;
    NSArchiver		*a = [NSArchiver new];

    [NSAutoreleasePool enableDoubleReleaseCheck:NO];
    for (i = 0; i < 10000; i++) {
	NSMutableData	*d;
	id	o;

	[a encodeRootObject: set];
	d = [a archiverData];
	if (u == nil) {
	    u = [[NSUnarchiver alloc] initForReadingWithData: d];
	}
	else {
	    [u resetUnarchiverWithData: d atIndex: 0];
	}
	o = [u decodeObject];
	[d setLength: 0];
	[a resetArchiver];
    }
    [a release];
    [u release];
    [arp release];
    printf("Time: %f\n", -[start timeIntervalSinceNow]);
  }

  /* Do the autorelease. */
  [arp release];
  
  exit(0);
}


/* An old, unused test. */
#else

#include <gnustep/base/all.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSAutoreleasePool.h>

@interface TestClass : NSObject
{
  id next_responder;
}

- (void)setNextResponder: anObject;
- nextResponder;
@end

@implementation TestClass

- (void)setNextResponder: anObject
{
  next_responder = anObject;
}

- nextResponder
{
  return next_responder;
}

// NSCoding protocol
- (void)encodeWithCoder:aCoder
{
  [super encodeWithCoder:aCoder];
  [aCoder encodeObjectReference:next_responder withName:@"Next Responder"];
}

- initWithCoder:aDecoder
{
  id d;
  [super initWithCoder:aDecoder];
  [aDecoder decodeObjectAt:&next_responder withName:&d];
  return self;
}
@end

////////////////////////////////////////

int main()
{
  id arp;
  id r1, r2;

  arp = [[NSAutoreleasePool alloc] init];

  // Create a simple loop
  r1 = [[TestClass alloc] init];
  r2 = [[TestClass alloc] init];
  [r1 setNextResponder: r2];
  [r2 setNextResponder: r1];

  printf("Writing\n");
  printf("%d\n", [r1 hash]);
  printf("%d\n", [r2 hash]);
  printf("%d\n", [[r1 nextResponder] hash]);
  printf("%d\n", [[r2 nextResponder] hash]);

  /* Write it to a file */
  {
    id d = [[NSMutableData alloc] init];
    id a = [[Archiver alloc] initForWritingWithMutableData: d];

    [a startEncodingInterconnectedObjects];
    [a encodeObject: r1 withName:@"one"];
    [a encodeObject: r2 withName:@"another"];
    [a finishEncodingInterconnectedObjects];

    [d writeToFile: @"./nsarchiver.dat" atomically:NO];

    [d release];
    [a release];
  }

  /* Release the object that was coded */
  [r1 release];
  [r2 release];

  /* Read it back in from the file */
  printf("\nReading:\n");
  {
    id d;
    id a = [Unarchiver newReadingFromFile:@"./nsarchiver.dat"];

    [a startDecodingInterconnectedObjects];
    [a decodeObjectAt: &r1 withName:&d];
    [a decodeObjectAt: &r2 withName:&d];
    [a finishDecodingInterconnectedObjects];
  }

  /* Display what we read, to make sure it matches what we wrote */
  {
    printf("%d\n", [r1 hash]);
    printf("%d\n", [r2 hash]);
    printf("%d\n", [[r1 nextResponder] hash]);
    printf("%d\n", [[r2 nextResponder] hash]);
  }

  /* Do the autorelease. */
  [arp release];

  exit(0);
}

#endif

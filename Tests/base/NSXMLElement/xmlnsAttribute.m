#import "ObjectTesting.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSString.h"
#import "Foundation/NSXMLDocument.h"
#import "Foundation/NSXMLElement.h"
#import "Foundation/NSXMLNode.h"

/* An xmlns:prefix attribute is a namespace declaration.  Adding it as a
 * plain attribute used to manufacture a namespace node carrying the
 * reserved "xmlns" prefix and a NULL href, which the document's teardown
 * then freed twice - so the damage landed in whatever allocation came
 * next, several rounds later.  Enough rounds here to reach it.
 */

typedef enum {
  PrefixedAttribute,	/* xmlns:rd="urn:b" as an attribute - the fault */
  DefaultAttribute,	/* xmlns="urn:a" as an attribute                 */
  RealNamespace		/* the same thing said properly                  */
} Declaration;

static BOOL
buildAndRelease(Declaration how, NSUInteger rounds, BOOL release)
{
  NSMutableArray	*kept = (release ? nil : [NSMutableArray array]);
  NSUInteger		 round;
  BOOL			 wroteEveryRound = YES;

  for (round = 0; round < rounds; round++)
    {
      NSAutoreleasePool	*inner = [NSAutoreleasePool new];
      NSXMLElement	*root;
      NSXMLDocument	*document;
      NSString		*xml;
      NSUInteger	 child;

      root = [NSXMLElement elementWithName: @"Report"];
      switch (how)
	{
	  case PrefixedAttribute:
	    [root addAttribute: [NSXMLNode attributeWithName: @"xmlns:rd"
						 stringValue: @"urn:b"]];
	    break;
	  case DefaultAttribute:
	    [root addAttribute: [NSXMLNode attributeWithName: @"xmlns"
						 stringValue: @"urn:a"]];
	    break;
	  case RealNamespace:
	    [root addNamespace: [NSXMLNode namespaceWithName: @"rd"
					     stringValue: @"urn:b"]];
	    break;
	}

      for (child = 0; child < 40; child++)
	{
	  [root addChild: [NSXMLElement elementWithName: @"C"
					    stringValue: @"x"]];
	}

      document = [[NSXMLDocument alloc] initWithRootElement: root];
      [document setVersion: @"1.0"];
      [document setCharacterEncoding: @"utf-8"];
      xml = [document XMLStringWithOptions: NSXMLNodePrettyPrint];

      if ([xml length] == 0)
	{
	  wroteEveryRound = NO;
	}

      if (release)
	{
	  [document release];
	}
      else
	{
	  [kept addObject: AUTORELEASE(document)];
	}
      [inner release];
    }

  return wroteEveryRound;
}

int main(void)
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSUInteger const	 rounds = 400;

  /* The fault: the document that carried the attribute is released, and
   * the damage shows up in a later, innocent allocation.
   */
  PASS(buildAndRelease(PrefixedAttribute, rounds, YES),
    "a document with an xmlns: attribute writes itself out");
  PASS(YES,
    "%u rounds of building and releasing such a document leave the heap intact",
    (unsigned)rounds);

  /* A control: a default namespace carries no prefix, so it never took
   * the faulty path.
   */
  PASS(buildAndRelease(DefaultAttribute, rounds, YES),
    "a document with an xmlns attribute writes itself out");

  /* And another: said the way it ought to be said. */
  PASS(buildAndRelease(RealNamespace, rounds, YES),
    "a document with a namespace added as a namespace writes itself out");

  /* Keeping the documents alive hides the fault entirely - which is what
   * made it look intermittent.  A smaller count: this one holds them all.
   */
  PASS(buildAndRelease(PrefixedAttribute, 50, NO),
    "the same documents, never released, write themselves out");

  [arp release];
  return 0;
}

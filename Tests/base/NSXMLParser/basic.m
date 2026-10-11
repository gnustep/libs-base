#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLParser.h>
int main()
{
  START_SET("NSXMLParser basic")
  NSXMLParser           *parser;
  Class                 c = NSClassFromString(@"GSSloppyXMLParser");

  parser = [c new];
  test_alloc(@"GSSloppyXMLParser");
  test_NSObject(@"GSSloppyXMLParser", [NSArray arrayWithObject: parser]);
  DESTROY(parser);

  parser = [NSXMLParser new];
  test_alloc(@"NSXMLParser");
  test_NSObject(@"NSXMLParser", [NSArray arrayWithObject: parser]);
  DESTROY(parser);

  END_SET("NSXMLParser basic")

  return 0;
}

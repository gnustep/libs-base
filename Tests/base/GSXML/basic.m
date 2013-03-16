#import <Foundation/Foundation.h>
#import "Testing.h"
#if     defined(GNUSTEP_BASE_LIBRARY) && (GS_USE_LIBXML == 1)
#import <GNUstepBase/GSXML.h>
#import "ObjectTesting.h"
int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  GSXMLDocument *doc;
  volatile GSXMLNamespace *namespace;
  NSMutableArray *iparams;
  NSMutableArray *oparams;
  GSXMLNode	*node;
  GSXMLRPC	*rpc;
  NSString	*str;
  NSData	*dat;

  TEST_FOR_CLASS(@"GSXMLDocument",[GSXMLDocument alloc],
    "GSXMLDocument +alloc returns a GSXMLDocument");
  
  TEST_FOR_CLASS(@"GSXMLDocument",[GSXMLDocument documentWithVersion: @"1.0"],
    "GSXMLDocument +documentWithVersion: returns a GSXMLDocument");
  
  TEST_FOR_CLASS(@"GSXMLNode",[GSXMLNode alloc],
    "GSXMLNode +alloc returns a GSXMLNode");
  
  TEST_FOR_CLASS(@"GSXMLRPC",[GSXMLRPC alloc],
    "GSXMLRPC +alloc returns a GSXMLRPC instance");

  NS_DURING
    node = [GSXMLNode new]; 
    PASS(node == nil, "GSXMLNode +new returns nil");
  NS_HANDLER
    PASS(node == nil, "GSXMLNode +new returns nil");
  NS_ENDHANDLER
  
  TEST_FOR_CLASS(@"GSXMLNamespace",[GSXMLNamespace alloc],
    "GSXMLNamespace +alloc returns a GSXMLNamespace");
  

  NS_DURING
    namespace = [GSXMLNamespace new]; 
    PASS(namespace == nil, "GSXMLNamespace +new returns nil");
  NS_HANDLER
    PASS(namespace == nil, "GSXMLNamespace +new returns nil");
  NS_ENDHANDLER
  
  doc = [GSXMLDocument documentWithVersion: @"1.0"];
  node = [doc makeNodeWithNamespace: nil name: @"nicola" content: nil]; 
  PASS (node != nil,"Can create a document node");
  
  
  [doc setRoot: node];
  PASS([[doc root] isEqual: node],"Can set document node as root node");
  
  [doc makeNodeWithNamespace: nil name: @"nicola" content: nil];
  [node makeChildWithNamespace: nil
			  name: @"paragraph"
		       content: @"Hi this is some text"];
  [node makeChildWithNamespace: nil
			  name: @"paragraph"
		       content: @"Hi this is even some more text"];
  [doc setRoot: node];
  PASS([[doc root] isEqual: node],
    "Can set a document node (with children) as root node");
  
  namespace = [node makeNamespaceHref: @"http: //www.gnustep.org"
			       prefix: @"gnustep"];
  PASS(namespace != nil,"Can create a node namespace");
  
  node = [doc makeNodeWithNamespace: namespace name: @"nicola" content: nil];
  PASS([[node namespace] isEqual: namespace],
    "Can create a node with a namespace");

  node = [doc makeNodeWithNamespace: namespace name: @"another" content: nil];
  PASS([[node namespace] isEqual: namespace],
    "Can create a node with same namespace as another node");
  
  PASS([[namespace prefix] isEqual: @"gnustep"],
    "A namespace remembers its prefix");
  

  rpc = [(GSXMLRPC*)[GSXMLRPC alloc] initWithURL: @"http://localhost/"];
  PASS(rpc != nil, "Can initialise an RPC instance");

  iparams = [NSMutableArray array];
  oparams = [NSMutableArray array];

  dat = [rpc buildMethod: @"method" params: nil];
  PASS(dat != nil, "Can build an empty method call (nil params)");
  str = [rpc parseMethod: dat params: oparams];
  PASS([str isEqual: @"method"] && [iparams isEqual: oparams],
    "Can parse an empty method call (nil params)");

  dat = [rpc buildMethod: @"method" params: iparams];
  PASS(dat != nil, "Can build an empty method call");
  str = [rpc parseMethod: dat params: oparams];
  PASS([str isEqual: @"method"] && [iparams isEqual: oparams],
    "Can parse an empty method call");

  [iparams addObject: @"a string"];
  dat = [rpc buildMethod: @"method" params: iparams];
  PASS(dat != nil, "Can build a method call with a string");
  str = [rpc parseMethod: dat params: oparams];
  PASS([str isEqual: @"method"] && [iparams isEqual: oparams],
    "Can parse a method call with a string");

  [rpc setCompact: YES];
  str = [rpc buildMethodCall: @"method" params: iparams];
  [rpc setCompact: NO];
  str = [str stringByReplacingString: @"<string>" withString: @""];
  str = [str stringByReplacingString: @"</string>" withString: @""];
  str = [rpc parseMethod: [str dataUsingEncoding: NSUTF8StringEncoding]
  		  params: oparams];
  PASS([str isEqual: @"method"] && [iparams isEqual: oparams],
    "Can parse a method call with a string without the <string> element");

  [iparams addObject: [NSNumber numberWithInt: 4]];
  dat = [rpc buildMethod: @"method" params: iparams];
  PASS(dat != nil, "Can build a method call with an integer");
  str = [rpc parseMethod: dat params: oparams];
  PASS([str isEqual: @"method"] && [iparams isEqual: oparams],
    "Can parse a method call with an integer");

  [iparams addObject: [NSNumber numberWithFloat: 4.5]];
  dat = [rpc buildMethod: @"method" params: iparams];
  PASS(dat != nil, "Can build a method call with a float");
  str = [rpc parseMethod: dat params: oparams];
  PASS([str isEqual: @"method"] && [iparams isEqual: oparams],
    "Can parse a method call with a float");

  [iparams addObject: [NSData dataWithBytes: "1234" length: 4]];
  dat = [rpc buildMethod: @"method" params: iparams];
  PASS(dat != nil, "Can build a method call with binary data");
  str = [rpc parseMethod: dat params: oparams];
  PASS([str isEqual: @"method"] && [iparams isEqual: oparams],
    "Can parse a method call with binary data");

  [rpc setTimeZone: [NSTimeZone systemTimeZone]];
  [iparams addObject: [NSDate date]];
  dat = [rpc buildMethod: @"method" params: iparams];
  PASS(dat != nil, "Can build a method call with a date");
  str = [rpc parseMethod: dat params: oparams];
  PASS([str isEqual: @"method"]
    && [[iparams description] isEqual: [oparams description]],
    "Can parse a method call with a date");


  [arp release]; arp = nil;
  return 0;
}
#else
int main(int argc,char **argv)
{
  START_SET("GSXML")
    SKIP("GSXML support unavailable");
  END_SET("GSXML")
  return 0;
}
#endif

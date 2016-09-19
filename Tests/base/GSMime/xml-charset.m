#if     defined(GNUSTEP_BASE_LIBRARY)
#import <Foundation/Foundation.h>
#import <GNUstepBase/GSMime.h>
#import "Testing.h"

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSString *xml = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?><html></html>";
  NSString *charset = nil;
  testHopeful = YES;
  PASS_RUNS(charset = [GSMimeDocument charsetForXml: xml], "Can determine cahrset of xml document.");
  DESTROY(arp);
}
#else
int main(int argc,char **argv)
{
  return 0;
}
#endif

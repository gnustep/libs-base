#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

@interface	GSFileURLHandle : NSURLHandle
+ (void) _setFileCacheSize: (NSUInteger) size;
+ (NSCache *) _fileCache;
@end

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSString *execPath;
  NSString *path;
  NSURL *url;
  NSCache *cache;
  NSData *data;
  GSFileURLHandle *fileHandle;
  Class fileHandleClass;
  

  execPath = [[NSBundle mainBundle] resourcePath];
  NSLog(@"Resource Path: %@", execPath);
  // Assuming executable is located in obj subdir
  path = [NSString stringWithFormat: @"%@/testData.txt", execPath];
  url = [NSURL fileURLWithPath: path];

  fileHandleClass = [NSURLHandle URLHandleClassForURL: url];
  fileHandle = [[fileHandleClass alloc] initWithURL: url cached: YES];
  cache = [GSFileURLHandle _fileCache];

  GSFileURLHandle *h = [cache objectForKey: [url path]];
  PASS(h == nil, "Cache does not store unloaded file handle");

  data = [fileHandle loadInForeground];
  PASS(data != nil, "Data is valid");

  h = [cache objectForKey: [url path]];
  PASS(h != nil, "Cache stores loaded file handle");
  PASS([fileHandle isEqualTo: h], "File handles are equivalent");
  
  [fileHandle release];
  [arp release]; arp = nil;
  return 0;
}
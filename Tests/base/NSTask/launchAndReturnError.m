#import <Foundation/NSTask.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSData.h>
#import <Foundation/NSAutoreleasePool.h>

#import "ObjectTesting.h" 

int main()
{
  NSTask *task;
  NSPipe *outPipe;
  NSFileManager *mgr;
  NSString      *helpers;
  NSFileHandle  *outHandle;
  NSAutoreleasePool *arp;
  NSData *data = nil;

  arp = [[NSAutoreleasePool alloc] init];

  mgr = [NSFileManager defaultManager];
  helpers = [mgr currentDirectoryPath];
  helpers = [helpers stringByAppendingPathComponent: @"Helpers"];
  helpers = [helpers stringByAppendingPathComponent: @"obj"];

  task = [[NSTask alloc] init];
  outPipe = [[NSPipe pipe] retain];
  [task setLaunchPath: [helpers stringByAppendingPathComponent: @"testcat"]];
  [task setArguments: [NSArray arrayWithObjects: nil]];
  [task setStandardOutput: outPipe]; 
  outHandle = [outPipe fileHandleForReading];

  [task launch];
  PASS([task standardOutput] == outPipe, "standardOutput returns pipe");
  data = [outHandle readDataToEndOfFile];
  PASS([data length] > 0, "was able to read data from subtask");
  NSLog(@"Data was %*.*s", [data length], [data length], [data bytes]);
  [task terminate];
  [outPipe release];
  
  [arp release];

  return 0;
}

#include "Foundation/NSObjCRuntime.h"
#import "Testing.h"
#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSFileHandle *writeFH, *readFH;
  NSString *tempPath = [NSString stringWithFormat:@"%@/%@", NSTemporaryDirectory(), [[NSProcessInfo processInfo] globallyUniqueString]];
  NSData *writeData = [@"GNUstep-Testing" dataUsingEncoding: NSUTF8StringEncoding];
  NSData *readData;
  NSError *error = nil;

  PASS([@"" writeToFile: tempPath atomically: YES],
       "Created temp file");

  writeFH = [NSFileHandle fileHandleForWritingAtPath: tempPath];
  PASS(writeFH != nil, "+fileHandleForWritingAtPath: opened successfully");

  BOOL writeResult = [writeFH writeData: writeData error: &error];
  PASS(writeResult && error == nil,
       "-writeData:error: wrote successfully");

  [writeFH closeFile];

  readFH = [NSFileHandle fileHandleForReadingAtPath: tempPath];
  PASS(readFH != nil, "+fileHandleForReadingAtPath: opened successfully");

  readData = [readFH readDataUpToLength: [writeData length] error: &error];
  PASS(error == nil && [readData isEqual: writeData],
       "-readDataUpToLength:error: returns correct data");

  [readFH seekToFileOffset: 0];

  readData = [readFH readDataToEndOfFileAndReturnError: &error];
  PASS(error == nil && [readData isEqual: writeData],
       "-readDataToEndOfFileAndReturnError: returns correct data");


  [readFH closeFile];
  [[NSFileManager defaultManager] removeItemAtPath: tempPath error: NULL];

  [arp release];
  return 0;
}

#import "ObjectTesting.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

static NSString *
written(id plist, NSPropertyListFormat format, NSString *name)
{
  NSString      *path;
  NSData        *data;

  path = [NSTemporaryDirectory() stringByAppendingPathComponent: name];
  data = [NSPropertyListSerialization dataWithPropertyList: plist
                                                    format: format
                                                   options: 0
                                                     error: NULL];
  [data writeToFile: path atomically: YES];
  return path;
}

int main()
{
  ENTER_POOL
  NSDictionary          *dict;
  NSArray               *array;
  NSString              *path;

  dict = [NSDictionary dictionaryWithObjectsAndKeys:
    @"a.b.c", @"access", [NSNumber numberWithDouble: 1.5], @"expires",
    [NSArray arrayWithObject: @"x"], @"list", nil];
  array = [NSArray arrayWithObjects:
    @"one", [NSNumber numberWithInt: 2], dict, nil];

  START_SET("a binary property list is read back")

  path = written(dict, NSPropertyListBinaryFormat_v1_0, @"plist-binary-dict");
  PASS_EQUAL([NSDictionary dictionaryWithContentsOfFile: path], dict,
    "+[NSDictionary dictionaryWithContentsOfFile:]")
  PASS_EQUAL([NSDictionary dictionaryWithContentsOfURL:
    [NSURL fileURLWithPath: path]], dict,
    "+[NSDictionary dictionaryWithContentsOfURL:]")

  path = written(array, NSPropertyListBinaryFormat_v1_0, @"plist-binary-array");
  PASS_EQUAL([NSArray arrayWithContentsOfFile: path], array,
    "+[NSArray arrayWithContentsOfFile:]")
  PASS_EQUAL([NSArray arrayWithContentsOfURL: [NSURL fileURLWithPath: path]],
    array, "+[NSArray arrayWithContentsOfURL:]")
  PASS([[NSArray arrayWithContentsOfFile: path]
    isKindOfClass: [NSMutableArray class]],
    "and the array is mutable, as before")

  END_SET("a binary property list is read back")

  START_SET("text property lists are read as before")

  path = written(dict, NSPropertyListXMLFormat_v1_0, @"plist-xml-dict");
  PASS_EQUAL([NSDictionary dictionaryWithContentsOfFile: path], dict, "XML")
  path = written(array, NSPropertyListOpenStepFormat, @"plist-openstep-array");
  PASS([[NSArray arrayWithContentsOfFile: path] count] == 3, "OpenStep")

  END_SET("text property lists are read as before")

  START_SET("anything else is nil")

  path = [NSTemporaryDirectory() stringByAppendingPathComponent: @"plist-none"];
  [[NSData dataWithBytes: "\x01\x02\xff" length: 3]
    writeToFile: path atomically: YES];
  PASS([NSDictionary dictionaryWithContentsOfFile: path] == nil,
    "bytes that are no property list")
  path = written(array, NSPropertyListBinaryFormat_v1_0, @"plist-binary-array");
  PASS([NSDictionary dictionaryWithContentsOfFile: path] == nil,
    "an array, for a dictionary")
  PASS([NSDictionary dictionaryWithContentsOfFile:
    @"/nonexistent/plist"] == nil, "no file")

  END_SET("anything else is nil")

  LEAVE_POOL
  return 0;
}

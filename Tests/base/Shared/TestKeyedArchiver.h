#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

@interface TestKeyedArchiver : NSKeyedArchiver
{
  NSMutableArray *_keys;
}
- (NSArray *) capturedKeys;
@end

@implementation TestKeyedArchiver
- (id) init
{
  self = [super init];
  if (self != nil)
    {
      _keys = [[NSMutableArray alloc] init];
    }
  return self;
}

- (void) dealloc
{
  [_keys release];
  [super dealloc];
}

- (void) encodeObject: (id)object forKey: (NSString *)key
{
  if (key != nil)
    {
      [_keys addObject: key];
    }
  [super encodeObject: object forKey: key];
}

- (void) encodeInt: (int)value forKey: (NSString *)key
{
  if (key != nil)
    {
      [_keys addObject: key];
    }
  [super encodeInt: value forKey: key];
}

- (void) encodeInteger: (NSInteger)value forKey: (NSString *)key
{
  if (key != nil)
    {
      [_keys addObject: key];
    }
  [super encodeInteger: value forKey: key];
}

- (void) encodeBool: (BOOL)value forKey: (NSString *)key
{
  if (key != nil)
    {
      [_keys addObject: key];
    }
  [super encodeBool: value forKey: key];
}

- (void) encodeDouble: (double)value forKey: (NSString *)key
{
  if (key != nil)
    {
      [_keys addObject: key];
    }
  [super encodeDouble: value forKey: key];
}

- (void) encodeInt64: (int64_t)value forKey: (NSString *)key
{
  if (key != nil)
    {
      [_keys addObject: key];
    }
  [super encodeInt64: value forKey: key];
}

- (NSArray *) capturedKeys
{
  return _keys;
}
@end

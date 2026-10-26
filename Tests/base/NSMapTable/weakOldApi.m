#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

@interface Heavy : NSObject
{
  NSString	*_name;
}
- (instancetype) initWithName: (NSString*)name;
@end

@implementation Heavy
- (void) dealloc
{
  DESTROY(_name);
  DEALLOC
}

- (instancetype) initWithName: (NSString*)name
{
  if ((self = [super init]))
    {
      ASSIGN(self->_name, name);
    }
  return self;
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"Heavy(%@)", _name];
}

- (NSString*) name
{
  return _name;
}

@end


#define KEY(x) ((void* _Nullable) ((uintptr_t) x))

static void insert(NSMapTable* cache, NSUInteger key, Heavy* value)
{
  NSMapInsert(cache, KEY(key), (__bridge const void* _Nullable) value);
}

static Heavy* _Nullable get(NSMapTable* cache, NSUInteger key)
{
  const void* _Nullable retrieved = NSMapGet(cache, KEY(key));
  return (__bridge Heavy* _Nullable) retrieved;
}

int main(int argc, const char * argv[])
{
  ENTER_POOL
  NSUInteger	key = 5555;
  Heavy		*value;
  Heavy		*retrieved;

  // Initialize the map table.
  NSPointerFunctionsOptions keyOptions =
    NSPointerFunctionsOpaqueMemory
    | NSPointerFunctionsIntegerPersonality;
  NSPointerFunctionsOptions valueOptions =
    NSPointerFunctionsWeakMemory
    | NSPointerFunctionsObjectPersonality;
  NSMapTable	*cache;

  ENTER_POOL

  cache = [[NSMapTable alloc] initWithKeyOptions: keyOptions
				    valueOptions: valueOptions
					capacity: 256];

  // Add an entry using an integer key.  Since at least one of the NSMapTable
  // types (the key type) is not an object type, the recommended way to access
  // this NSMapTable is via the C interface, not the Objective-C one.
  value = AUTORELEASE([[Heavy alloc] initWithName: @"Fives"]);
  insert(cache, key, value);

  // Retrieve the entry.  We expect to get the value back.
  retrieved = get(cache, key);

  PASS(retrieved == value, "recovered value from map")

  // Clear the strong references.
  value = nil;
  retrieved = nil;

  // Potentially prune the cache.
  [cache count];

  LEAVE_POOL

  // Retrieve the entry again.  We may or may not get the value back.
  retrieved = get(cache, key);
  NSLog(@"Retrieved value (maybe)   : %@", retrieved);
  DESTROY(cache);
  LEAVE_POOL
  return 0;
}

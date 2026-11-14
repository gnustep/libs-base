#import "Testing.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/* A value which is never equal to anything, not even to itself, so the
 * only way two dictionaries holding it can be equal is by identity.
 */
@interface NeverEqual : NSObject
@end
@implementation NeverEqual
- (BOOL) isEqual: (id)other
{
  return NO;
}
- (NSUInteger) hash
{
  return 0;
}
@end

/* A minimal dictionary subclass, so that the comparison is done by the
 * abstract NSDictionary implementation rather than by GSDictionary.
 */
@interface WrappedDictionary : NSDictionary
{
  NSDictionary	*inner;
}
@end
@implementation WrappedDictionary
- (id) initWithObjects: (const id[])objects
	       forKeys: (const id <NSCopying>[])keys
		 count: (NSUInteger)count
{
  if (nil != (self = [super init]))
    {
      inner = [[NSDictionary alloc] initWithObjects: objects
					    forKeys: keys
					      count: count];
    }
  return self;
}
- (void) dealloc
{
  [inner release];
  [super dealloc];
}
- (NSUInteger) count
{
  return [inner count];
}
- (id) objectForKey: (id)aKey
{
  return [inner objectForKey: aKey];
}
- (NSEnumerator*) keyEnumerator
{
  return [inner keyEnumerator];
}
- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state
				   objects: (__unsafe_unretained id[])stackbuf
				     count: (NSUInteger)len
{
  return [inner countByEnumeratingWithState: state
				    objects: stackbuf
				      count: len];
}
@end

static NSMutableDictionary *
contents(unsigned count, id value)
{
  NSMutableDictionary	*d = [NSMutableDictionary dictionary];
  unsigned		i;

  for (i = 0; i < count; i++)
    {
      [d setObject: (nil == value ? (id)[NSNumber numberWithUnsignedInt: i]
	: value) forKey: [NSString stringWithFormat: @"key%u", i]];
    }
  return d;
}

static void
testClass(Class c)
{
  unsigned	count;

  for (count = 1; count <= 12; count++)
    {
      NSMutableDictionary	*m = contents(count, nil);
      NSDictionary		*d = [[c alloc] initWithDictionary: m];
      NSDictionary		*n;
      NSMutableDictionary	*changed;

      PASS([d isEqual: m] && [m isEqual: d],
	"%s with %u entries is equal to its contents",
	class_getName(c), count)

      changed = [[m mutableCopy] autorelease];
      [changed setObject: @"other" forKey: @"key0"];
      PASS(NO == [d isEqual: changed] && NO == [changed isEqual: d],
	"%s with %u entries differs when a value differs",
	class_getName(c), count)

      changed = [[m mutableCopy] autorelease];
      [changed removeObjectForKey: @"key0"];
      [changed setObject: [NSNumber numberWithInt: 0] forKey: @"other"];
      PASS(NO == [d isEqual: changed] && NO == [changed isEqual: d],
	"%s with %u entries differs when a key differs",
	class_getName(c), count)
      [d release];

      m = contents(count, AUTORELEASE([NeverEqual new]));
      d = [[c alloc] initWithDictionary: m];
      n = [[c alloc] initWithDictionary: m];
      PASS(d != n && ![d isEqual: n] && ![n isEqual: d],
	"%s with %u identical non-reflexive values is equal",
	class_getName(c), count)
      [n release];
      [d release];
    }
}

int
main(void)
{
  ENTER_POOL

  testClass([NSDictionary class]);
  testClass([NSMutableDictionary class]);
  testClass([WrappedDictionary class]);

  LEAVE_POOL
  return 0;
}

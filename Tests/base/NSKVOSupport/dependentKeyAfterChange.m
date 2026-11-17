#import <Foundation/Foundation.h>
#import "Testing.h"

/* A key that depends on a key path through another object
 * (+keyPathsForValuesAffecting<Key> returning @"model.x") must keep that
 * dependency after the key itself has changed.  A change of the key detaches
 * the observers further along the key paths it depends on and has to attach
 * them again when the change completes.
 *
 * Validated on macOS: every change of model.x notifies observers of total,
 * whether or not total has changed before.
 */

@interface Model : NSObject
{
  NSInteger	x;
}

- (NSInteger) x;
- (void) setX: (NSInteger)value;
@end

@implementation Model

- (NSInteger) x
{
  return x;
}

- (void) setX: (NSInteger)value
{
  x = value;
}

@end

@interface Owner : NSObject
{
  Model	*model;
}

- (Model *) model;
- (NSInteger) total;
- (void) setTotal: (NSInteger)value;
@end

@implementation Owner

+ (NSSet *) keyPathsForValuesAffectingTotal
{
  return [NSSet setWithObject: @"model.x"];
}

- (id) init
{
  if (nil != (self = [super init]))
    {
      model = [Model new];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(model);
  DEALLOC
}

- (Model *) model
{
  return model;
}

- (NSInteger) total
{
  return [model x];
}

- (void) setTotal: (NSInteger)value
{
  [model setX: value];
}

@end

@interface Counter : NSObject
{
@public
  NSUInteger	count;
  id		lastNew;
}
@end

@implementation Counter

- (void) dealloc
{
  RELEASE(lastNew);
  DEALLOC
}

- (void) observeValueForKeyPath: (NSString*)keyPath
		       ofObject: (id)object
			 change: (NSDictionary*)change
			context: (void*)context
{
  count++;
  ASSIGN(lastNew, [change objectForKey: NSKeyValueChangeNewKey]);
}

@end

typedef enum {
  ChangeBySetter,
  ChangeByWillDid,
  ChangeByNestedWillDid
} ChangeKind;

static void
changeTotal(Owner *owner, ChangeKind kind)
{
  switch (kind)
    {
      case ChangeBySetter:
	[owner setTotal: 2];
	break;
      case ChangeByWillDid:
	[owner willChangeValueForKey: @"total"];
	[owner didChangeValueForKey: @"total"];
	break;
      case ChangeByNestedWillDid:
	[owner willChangeValueForKey: @"total"];
	[owner willChangeValueForKey: @"total"];
	[owner didChangeValueForKey: @"total"];
	[owner didChangeValueForKey: @"total"];
	break;
    }
}

static void
testDependencyAfterChange(ChangeKind kind, const char *how)
{
  Owner		*owner = AUTORELEASE([Owner new]);
  Counter	*counter = AUTORELEASE([Counter new]);

  [owner addObserver: counter
	  forKeyPath: @"total"
	     options: NSKeyValueObservingOptionNew
	     context: NULL];

  [[owner model] setX: 1];
  PASS(counter->count == 1,
    "a change of model.x notifies observers of total before %s", how);

  changeTotal(owner, kind);

  counter->count = 0;
  [[owner model] setX: 3];
  PASS(counter->count == 1,
    "a change of model.x notifies observers of total after %s", how);
  PASS_EQUAL(counter->lastNew, [NSNumber numberWithInteger: 3],
    "the notification after %s carries the new value of total", how);

  counter->count = 0;
  [[owner model] setX: 4];
  PASS(counter->count == 1,
    "a second change of model.x notifies observers of total after %s", how);

  [owner removeObserver: counter forKeyPath: @"total"];

  counter->count = 0;
  [[owner model] setX: 5];
  PASS(counter->count == 0,
    "a change of model.x does not notify a removed observer after %s", how);
}

int
main(void)
{
  START_SET("dependent key after a change of the key")

  testDependencyAfterChange(ChangeBySetter, "the setter of total");
  testDependencyAfterChange(ChangeByWillDid,
    "a manual will/didChange of total");
  testDependencyAfterChange(ChangeByNestedWillDid,
    "a nested will/didChange of total");

  END_SET("dependent key after a change of the key")
  return 0;
}

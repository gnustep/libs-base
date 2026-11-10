#import <Foundation/Foundation.h>
#import "Testing.h"

/* A key whose value depends on a user default, declared through
 * +keyPathsForValuesAffecting<Key> with a key path through a plain accessor
 * returning the standard user defaults.
 *
 * Validated on macOS 26.6.2 (25G83): observers of the dependent key get its
 * own values rather than those of the default, and both the old and the new
 * value are read after the default has changed.
 */

static NSString *defaultKey = @"KVODependencyDefault";

@interface State : NSObject
@end

@implementation State

+ (NSSet *) keyPathsForValuesAffectingDerived
{
  return [NSSet setWithObjects: @"userDefaults.KVODependencyOther",
    @"userDefaults.KVODependencyDefault", @"userDefaults.KVODependencyThird",
    nil];
}

- (NSUserDefaults *) userDefaults
{
  return [NSUserDefaults standardUserDefaults];
}

- (BOOL) derived
{
  /* Deliberately not the value of the default itself. */
  return [[NSUserDefaults standardUserDefaults] integerForKey: defaultKey] == 0;
}

@end

@interface View : NSObject
{
  State *state;
}
- (State *) state;
- (void) setState: (State *)s;
@end

@implementation View
- (id) init
{
  if (nil != (self = [super init]))
    {
      state = [State new];
    }
  return self;
}
- (void) dealloc
{
  [state release];
  [super dealloc];
}
- (State *) state
{
  return state;
}
- (void) setState: (State *)s
{
  ASSIGN(state, s);
}
@end

@interface Model : NSObject
{
  View *view;
}
- (id) initWithView: (View *)v;
- (View *) view;
@end

@implementation Model
- (id) initWithView: (View *)v
{
  if (nil != (self = [super init]))
    {
      view = [v retain];
    }
  return self;
}
- (void) dealloc
{
  [view release];
  [super dealloc];
}
- (View *) view
{
  return view;
}
@end

@interface Observer : NSObject
{
@public
  NSInteger	count;
  id		lastOld;
  id		lastNew;
}
@end

@implementation Observer
- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
			 change: (NSDictionary *)change
			context: (void *)context
{
  count++;
  ASSIGN(lastOld, [change objectForKey: NSKeyValueChangeOldKey]);
  ASSIGN(lastNew, [change objectForKey: NSKeyValueChangeNewKey]);
}
- (void) dealloc
{
  RELEASE(lastOld);
  RELEASE(lastNew);
  [super dealloc];
}
@end

static void
setDefault(NSInteger value, BOOL viaKVC)
{
  NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];

  if (viaKVC)
    {
      [defs setValue: [NSNumber numberWithInteger: value]
	  forKeyPath: defaultKey];
    }
  else
    {
      [defs setInteger: value forKey: defaultKey];
    }
}

static void
check(id object, NSString *keyPath, BOOL viaKVC, NSString *description)
{
  Observer		*obs = [Observer new];
  const char		*d = [description UTF8String];

  setDefault(0, NO);
  [object addObserver: obs
	   forKeyPath: keyPath
	      options: NSKeyValueObservingOptionNew
		      | NSKeyValueObservingOptionOld
	      context: NULL];

  setDefault(1, viaKVC);
  PASS(obs->count == 1, "%s: changing the default notifies once (%ld)",
    d, (long)obs->count)
  PASS_EQUAL(obs->lastOld, [NSNumber numberWithBool: NO],
    "%s: the observed key's value after the change is the old value", d)
  PASS_EQUAL(obs->lastNew, [NSNumber numberWithBool: NO],
    "%s: the new value of the observed key is reported", d)

  setDefault(0, viaKVC);
  PASS(obs->count == 2, "%s: changing it back notifies again (%ld)",
    d, (long)obs->count)
  PASS_EQUAL(obs->lastOld, [NSNumber numberWithBool: YES],
    "%s: the old value is again the value after the change", d)
  PASS_EQUAL(obs->lastNew, [NSNumber numberWithBool: YES],
    "%s: the new value is reported again", d)

  [object removeObserver: obs forKeyPath: keyPath];
  [obs release];
}

int
main(int argc, char *argv[])
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
  NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];
  View			*view = [[View new] autorelease];
  Model			*model = [[[Model alloc] initWithView: view] autorelease];
  Model			*model2 = [[[Model alloc] initWithView: view] autorelease];
  Observer		*o1;
  Observer		*o2;
  Observer		*direct;

  START_SET("dependent key through user defaults")

  check([view state], @"derived", NO, @"direct");
  check(view, @"state.derived", NO, @"one level");
  check(model, @"view.state.derived", NO, @"two levels");
  check(model, @"view.state.derived", YES, @"two levels, set through KVC");

  /* Two roots observing the same object through the same key path, and
   * another observer of the default itself. */
  setDefault(0, NO);
  o1 = [[Observer new] autorelease];
  o2 = [[Observer new] autorelease];
  direct = [[Observer new] autorelease];
  [defs addObserver: direct forKeyPath: defaultKey
	    options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
	    context: NULL];
  [model addObserver: o1 forKeyPath: @"view.state.derived"
	     options: NSKeyValueObservingOptionNew
		     | NSKeyValueObservingOptionInitial
	     context: NULL];
  [model2 addObserver: o2 forKeyPath: @"view.state.derived"
	      options: NSKeyValueObservingOptionNew
		      | NSKeyValueObservingOptionInitial
	      context: NULL];
  o1->count = o2->count = 0;
  setDefault(1, YES);
  PASS(direct->count == 1, "the default's own observer is notified")
  PASS_EQUAL(direct->lastOld, [NSNumber numberWithInteger: 0],
    "the default's own observer gets the old value of the default")
  PASS_EQUAL(direct->lastNew, [NSNumber numberWithInteger: 1],
    "the default's own observer gets the new value of the default")
  PASS(o1->count == 1 && o2->count == 1,
    "two roots on the same object are both notified (%ld, %ld)",
    (long)o1->count, (long)o2->count)
  PASS_EQUAL(o1->lastNew, [NSNumber numberWithBool: NO],
    "the first root gets the new value of the observed key")
  PASS_EQUAL(o2->lastNew, [NSNumber numberWithBool: NO],
    "the second root gets the new value of the observed key")

  /* Replace an object in the middle of the observed key path. */
  [view setState: [[State new] autorelease]];
  o1->count = o2->count = 0;
  setDefault(0, YES);
  PASS(o1->count == 1 && o2->count == 1,
    "after replacing the state, both roots are notified (%ld, %ld)",
    (long)o1->count, (long)o2->count)
  PASS_EQUAL(o1->lastNew, [NSNumber numberWithBool: YES],
    "after replacing the state, the new value is reported")

  [model removeObserver: o1 forKeyPath: @"view.state.derived"];
  [model2 removeObserver: o2 forKeyPath: @"view.state.derived"];
  [defs removeObserver: direct forKeyPath: defaultKey];
  [defs removeObjectForKey: defaultKey];

  END_SET("dependent key through user defaults")

  [pool release];
  return 0;
}

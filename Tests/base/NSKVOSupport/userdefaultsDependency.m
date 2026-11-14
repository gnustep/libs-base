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

/* The value of the default when it is not set. */
static const NSInteger registeredValue = 5;

/* The derived value never equals the default it is computed from. */
#define DERIVED(v)	[NSNumber numberWithInteger: (v) + 10]

@interface State : NSObject
@end

@implementation State

/* Other defaults are included so that the defaults have several key
 * observers for the same dependent key. */
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

- (NSInteger) derived
{
  return [[NSUserDefaults standardUserDefaults] integerForKey: defaultKey] + 10;
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
  RELEASE(state);
  DEALLOC
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
      view = RETAIN(v);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(view);
  DEALLOC
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
  NSInteger	priorCount;
  id		priorOld;
  id		priorNew;
}

@end

@implementation Observer

- (void) observeValueForKeyPath: (NSString*)keyPath
		       ofObject: (id)object
			 change: (NSDictionary*)change
			context: (void*)context
{
  id	old = [change objectForKey: NSKeyValueChangeOldKey];
  id	new = [change objectForKey: NSKeyValueChangeNewKey];

  if ([[change objectForKey: NSKeyValueChangeNotificationIsPriorKey] boolValue])
    {
      priorCount++;
      ASSIGN(priorOld, old);
      ASSIGN(priorNew, new);
    }
  else
    {
      count++;
      ASSIGN(lastOld, old);
      ASSIGN(lastNew, new);
    }
}

- (void) dealloc
{
  RELEASE(lastOld);
  RELEASE(lastNew);
  RELEASE(priorOld);
  RELEASE(priorNew);
  DEALLOC
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
  NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];
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
  PASS_EQUAL(obs->lastOld, DERIVED(1),
    "%s: the observed key's value after the change is the old value", d)
  PASS_EQUAL(obs->lastNew, DERIVED(1),
    "%s: the new value of the observed key is reported", d)

  setDefault(1, viaKVC);
  PASS(obs->count == 1, "%s: writing the same value does not notify (%ld)",
    d, (long)obs->count)

  setDefault(0, viaKVC);
  PASS(obs->count == 2, "%s: changing it back notifies again (%ld)",
    d, (long)obs->count)
  PASS_EQUAL(obs->lastOld, DERIVED(0),
    "%s: the old value is again the value after the change", d)
  PASS_EQUAL(obs->lastNew, DERIVED(0),
    "%s: the new value is reported again", d)

  [defs removeObjectForKey: defaultKey];
  PASS(obs->count == 3, "%s: removing the default notifies (%ld)",
    d, (long)obs->count)
  PASS_EQUAL(obs->lastOld, DERIVED(registeredValue),
    "%s: after removal the old value is the value after the change", d)
  PASS_EQUAL(obs->lastNew, DERIVED(registeredValue),
    "%s: after removal the new value is based on the registered default", d)

  [object removeObserver: obs forKeyPath: keyPath];
  RELEASE(obs);
}

int
main(void)
{
  ENTER_POOL
  NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];
  View			*view = AUTORELEASE([View new]);
  Model			*model = AUTORELEASE([[Model alloc] initWithView: view]);
  Model			*model2 = AUTORELEASE([[Model alloc] initWithView: view]);
  Observer		*o1;
  Observer		*o2;
  Observer		*direct;
  Observer		*prior;

  START_SET("dependent key through user defaults")

  /* Only the new KVO implementation reports the observed key's values. */
  if (Nil == NSClassFromString(@"_NSKVOKeypathObserver"))
    {
      testHopeful = YES;
    }

  [defs registerDefaults: [NSDictionary dictionaryWithObject:
    [NSNumber numberWithInteger: registeredValue] forKey: defaultKey]];

  check([view state], @"derived", NO, @"direct");
  check(view, @"state.derived", NO, @"one level");
  check(model, @"view.state.derived", NO, @"two levels");
  check(model, @"view.state.derived", YES, @"two levels, set through KVC");

  /* Prior notifications also report the value after the change, while
   * those of the default itself report its value before the change. */
  setDefault(0, NO);
  prior = AUTORELEASE([Observer new]);
  direct = AUTORELEASE([Observer new]);
  [model addObserver: prior forKeyPath: @"view.state.derived"
	     options: NSKeyValueObservingOptionNew
		     | NSKeyValueObservingOptionOld
		     | NSKeyValueObservingOptionPrior
	     context: NULL];
  [defs addObserver: direct forKeyPath: defaultKey
	    options: NSKeyValueObservingOptionNew
		    | NSKeyValueObservingOptionOld
		    | NSKeyValueObservingOptionPrior
	    context: NULL];
  setDefault(1, YES);
  PASS(prior->priorCount == 1 && prior->count == 1,
    "a prior observer is notified before and after the change (%ld, %ld)",
    (long)prior->priorCount, (long)prior->count)
  PASS_EQUAL(prior->priorOld, DERIVED(1),
    "the prior notification reports the value after the change as old value")
  PASS(nil == prior->priorNew, "the prior notification has no new value")
  PASS_EQUAL(prior->lastNew, DERIVED(1),
    "the notification after the change reports the new value")
  PASS(direct->priorCount == 1 && direct->count == 1,
    "the default's own observer gets a prior notification (%ld, %ld)",
    (long)direct->priorCount, (long)direct->count)
  PASS_EQUAL(direct->priorOld, [NSNumber numberWithInteger: 0],
    "the default's own prior notification reports the default's old value")
  PASS_EQUAL(direct->lastOld, [NSNumber numberWithInteger: 0],
    "the default's own observer gets the old value of the default")
  PASS_EQUAL(direct->lastNew, [NSNumber numberWithInteger: 1],
    "the default's own observer gets the new value of the default")
  [model removeObserver: prior forKeyPath: @"view.state.derived"];
  [defs removeObserver: direct forKeyPath: defaultKey];

  /* Two roots observing the same object through the same key path. */
  setDefault(0, NO);
  o1 = AUTORELEASE([Observer new]);
  o2 = AUTORELEASE([Observer new]);
  [model addObserver: o1 forKeyPath: @"view.state.derived"
	     options: NSKeyValueObservingOptionNew
		     | NSKeyValueObservingOptionInitial
	     context: NULL];
  [model2 addObserver: o2 forKeyPath: @"view.state.derived"
	      options: NSKeyValueObservingOptionNew
		      | NSKeyValueObservingOptionInitial
	      context: NULL];
  PASS(o1->count == 1 && o2->count == 1,
    "both roots get an initial notification (%ld, %ld)",
    (long)o1->count, (long)o2->count)
  PASS_EQUAL(o1->lastNew, DERIVED(0),
    "the initial notification reports the current value")
  o1->count = o2->count = 0;
  setDefault(1, YES);
  PASS(o1->count == 1 && o2->count == 1,
    "two roots on the same object are both notified (%ld, %ld)",
    (long)o1->count, (long)o2->count)
  PASS_EQUAL(o1->lastNew, DERIVED(1),
    "the first root gets the new value of the observed key")
  PASS_EQUAL(o2->lastNew, DERIVED(1),
    "the second root gets the new value of the observed key")

  /* Replace an object in the middle of the observed key path. */
  [view setState: AUTORELEASE([State new])];
  o1->count = o2->count = 0;
  setDefault(0, YES);
  PASS(o1->count == 1 && o2->count == 1,
    "after replacing the state, both roots are notified (%ld, %ld)",
    (long)o1->count, (long)o2->count)
  PASS_EQUAL(o1->lastNew, DERIVED(0),
    "after replacing the state, the new value is reported")

  [model removeObserver: o1 forKeyPath: @"view.state.derived"];
  [model2 removeObserver: o2 forKeyPath: @"view.state.derived"];
  [defs removeObjectForKey: defaultKey];

  END_SET("dependent key through user defaults")

  LEAVE_POOL
  return 0;
}

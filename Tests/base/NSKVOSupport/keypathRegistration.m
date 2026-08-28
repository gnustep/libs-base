/* An object in the middle of a key path may take charge of observer
   registration, in order to pass it on to the objects it holds.  That is how
   the gui library exposes an array controller's arranged objects.  Its
   -addObserver:forKeyPath:options:context: has to be used, otherwise a change
   to one of the held objects is never reported.
*/
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSKeyValueObserving.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <GNUstepBase/GNUstep.h>

#import "Testing.h"

static int registrations = 0;

@interface Element : NSObject
{
  NSString *_name;
}
- (NSString *) name;
- (void) setName: (NSString *)aName;
@end

@implementation Element
- (NSString *) name { return _name; }
- (void) setName: (NSString *)aName { ASSIGN(_name, aName); }
- (void) dealloc { RELEASE(_name); DEALLOC }
@end

/* Holds objects and passes registration on to them. */
@interface Registrar : NSObject
{
  NSArray *_elements;
}
- (id) initWithElements: (NSArray *)elements;
@end

@implementation Registrar

- (id) initWithElements: (NSArray *)elements
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(_elements, elements);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_elements);
  DEALLOC
}

- (id) valueForKey: (NSString *)key
{
  return [_elements valueForKey: key];
}

- (void) addObserver: (NSObject *)observer
          forKeyPath: (NSString *)keyPath
             options: (NSKeyValueObservingOptions)options
             context: (void *)context
{
  NSEnumerator *e = [_elements objectEnumerator];
  id element;

  registrations++;
  while ((element = [e nextObject]) != nil)
    {
      [element addObserver: observer
                forKeyPath: keyPath
                   options: options
                   context: context];
    }
}

- (void) removeObserver: (NSObject *)observer forKeyPath: (NSString *)keyPath
{
  NSEnumerator *e = [_elements objectEnumerator];
  id element;

  while ((element = [e nextObject]) != nil)
    {
      [element removeObserver: observer forKeyPath: keyPath];
    }
}

@end

@interface Holder : NSObject
{
  Registrar *_registrar;
}
- (Registrar *) registrar;
- (void) setRegistrar: (Registrar *)aRegistrar;
@end

@implementation Holder
- (Registrar *) registrar { return _registrar; }
- (void) setRegistrar: (Registrar *)aRegistrar { ASSIGN(_registrar, aRegistrar); }
- (void) dealloc { RELEASE(_registrar); DEALLOC }
@end

@interface Watcher : NSObject
{
@public
  int       count;
  NSString *lastKeyPath;
  id        lastObject;
}
@end

@implementation Watcher
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
  count++;
  ASSIGN(lastKeyPath, keyPath);
  lastObject = object;
}
- (void) dealloc { RELEASE(lastKeyPath); DEALLOC }
@end

int
main(int argc, char **argv)
{
  CREATE_AUTORELEASE_POOL(arp);
  Element *element = AUTORELEASE([[Element alloc] init]);
  Registrar *registrar;
  Holder *holder = AUTORELEASE([[Holder alloc] init]);
  Watcher *watcher = AUTORELEASE([[Watcher alloc] init]);

  [element setName: @"a"];
  registrar = AUTORELEASE([[Registrar alloc]
    initWithElements: [NSArray arrayWithObject: element]]);
  [holder setRegistrar: registrar];

  [holder addObserver: watcher
           forKeyPath: @"registrar.name"
              options: NSKeyValueObservingOptionNew
              context: NULL];

  PASS(registrations == 1,
       "the object in the middle of the key path registers the observation");

  [element setName: @"b"];

  PASS(watcher->count == 1,
       "changing a held object reports the key path");
  PASS_EQUAL(watcher->lastKeyPath, @"registrar.name",
             "the whole key path is reported");
  PASS(watcher->lastObject == holder,
       "the object of the notification is the one being observed");

  [holder removeObserver: watcher forKeyPath: @"registrar.name"];
  [element setName: @"c"];

  PASS(watcher->count == 1,
       "no notification arrives once the observer is removed");

  /* A plain array refuses an observer, and a key path through one reaches the
     array with the rest of the key path, so that registration raises too. */
  {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    [dict setObject: [NSArray arrayWithObject: element] forKey: @"list"];

    PASS_EXCEPTION([dict addObserver: watcher
                          forKeyPath: @"list.name"
                             options: NSKeyValueObservingOptionNew
                             context: NULL];,
      NSInvalidArgumentException,
      "a key path through a plain array raises");
  }

  /* An operator reads through the array rather than naming a property of the
     objects it holds, so it is accepted. */
  {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    BOOL raised = NO;

    [dict setObject: [NSArray arrayWithObject: element] forKey: @"list"];

    NS_DURING
      {
        [dict addObserver: watcher
               forKeyPath: @"list.@count"
                  options: NSKeyValueObservingOptionNew
                  context: NULL];
        [dict removeObserver: watcher forKeyPath: @"list.@count"];
      }
    NS_HANDLER
      {
        raised = YES;
      }
    NS_ENDHANDLER

    PASS(raised == NO,
      "a key path through an array to an operator is accepted");
  }

  DESTROY(arp);
  return 0;
}

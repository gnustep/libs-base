/**
 * The GSRunLoopCtxt stores context information to handle polling for
 * events.  This information is associated with a particular runloop
 * mode, and persists throughout the life of the runloop instance.
 *
 *	NB.  This class is private to NSRunLoop and must not be subclassed.
 */

#import "common.h"

#import "Foundation/NSError.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSNotificationQueue.h"
#import "Foundation/NSPort.h"
#import "Foundation/NSStream.h"
#define	GENERICCTXT	1
#import "GSRunLoopCtxt.h"
#import "GSRunLoopWatcher.h"
#import "GSPrivate.h"

#ifdef HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif

static SEL	wRelSel;
static SEL	wRetSel;
static IMP	wRelImp;
static IMP	wRetImp;

static void
wRelease(NSMapTable* t, void* w)
{
  (*wRelImp)((id)w, wRelSel);
}

static void
wRetain(NSMapTable* t, const void* w)
{
  (*wRetImp)((id)w, wRetSel);
}

static const NSMapTableValueCallBacks WatcherMapValueCallBacks = 
{
  wRetain,
  wRelease,
  0
};

@implementation	GSRunLoopCtxtBase
- (void) dealloc
{
  RELEASE(mode);
  RELEASE(timerHeap);
  GSIArrayEmpty(watchers);
  NSZoneFree(watchers->zone, (void*)watchers);
  DEALLOC
}
- (id) initWithMode: (NSString*)theMode extra: (void**)e
{
  if (nil != (self = [super init]))
    {
      NSZone	*z = [self zone];

      mode = [theMode copy];
      extra = *e;
      timerHeap = [[GSMinHeap allocWithZone: z]
	initWithCapacity: 100 andComparator: NULL];
      watchers = NSZoneMalloc(z, sizeof(GSIArray_t));
      GSIArrayInitWithZoneAndCapacity(watchers, z, 8);
    }
  return self;
}
- (BOOL) runnable
{
  return NO;
}
@end

@implementation	GSRunLoopCtxt

+ (void) initialize
{
  wRelSel = @selector(release);
  wRetSel = @selector(retain);
  wRelImp = [[GSRunLoopWatcher class] instanceMethodForSelector: wRelSel];
  wRetImp = [[GSRunLoopWatcher class] instanceMethodForSelector: wRetSel];
}

+ (id) allocWithZone: (NSZone*)z
{
  static Class	c = Nil;

  if (Nil == c)
    {
#if     defined(_WIN32)
      c = NSClassFromString(@"GSRunLoopCtxtWin32");
#else
      c = NSClassFromString(@"GSRunLoopCtxtUnix");
#endif
    }
  if (self == c)
    {
      return [super allocWithZone: z];
    }
  else
    {
      return [c allocWithZone: z];
    }
}

+ (BOOL) awakenedBefore: (NSDate*)when
{
  return NO;
}

- (void) dealloc
{
  GSIArrayEmpty(performers);
  NSZoneFree(performers->zone, (void*)performers);
  GSIArrayEmpty(_trigger);
  NSZoneFree(_trigger->zone, (void*)_trigger);
  DEALLOC
}

- (void) endEvent: (void*)data
              for: (GSRunLoopWatcher*)watcher
{
  if (!completed)
    {
      unsigned i = GSIArrayCount(_trigger);

      while (i-- > 0)
        {
          GSIArrayItem  item = GSIArrayItemAtIndex(_trigger, i);

          if (item.obj == (id)watcher)
            {
              GSIArrayRemoveItemAtIndex(_trigger, i);
              return;
            }
        }
    }
}

/**
 * Mark this poll context as having completed, so that if we are
 * executing a re-entrant poll, the enclosing poll operations
 * know they can stop what they are doing because an inner
 * operation has done the job.
 */
- (void) endPoll
{
  completed = YES;
}

- (id) initWithMode: (NSString*)theMode extra: (void**)e
{
  if (nil != (self = [super initWithMode: theMode extra: e]))
    {
      NSZone	*z = [self zone];

      performers = NSZoneMalloc(z, sizeof(GSIArray_t));
      GSIArrayInitWithZoneAndCapacity(performers, z, 8);
      _trigger = NSZoneMalloc(z, sizeof(GSIArray_t));
      GSIArrayInitWithZoneAndCapacity(_trigger, z, 8);
    }
  return self;
}

- (BOOL) pollUntil: (int)milliseconds within: (NSArray*)contexts
{
  return NO;
}

- (BOOL) runnable
{
  return YES;
}

- (const NSMapTableValueCallBacks) watcherCallbacks
{
  return WatcherMapValueCallBacks;
}

@end

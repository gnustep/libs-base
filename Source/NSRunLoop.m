/** Implementation of object for waiting on several input sources
  NSRunLoop.m

   Copyright (C) 1996-1999 Free Software Foundation, Inc.

   Original by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996
   OPENSTEP version by: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: August 1997

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSRunLoop class reference</title>
   $Date$ $Revision$
*/

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSPort.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSDebug.h>

#ifdef HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif
#ifdef HAVE_POLL_H
#include <poll.h>
#endif
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#include <time.h>
#include <limits.h>
#include <string.h>		/* for memset() */


static NSDate	*theFuture = nil;

extern BOOL	GSCheckTasks();

#ifdef	HAVE_POLL
typedef struct {
  int		limit;
  short		*index;
} pollextra;
#endif


/*
 *	The 'GSRunLoopWatcher' class was written to permit the (relatively)
 *	easy addition of new events to be watched for in the runloop.
 *
 *	To add a new type of event, the 'RunLoopEventType' enumeration must be
 *	extended, and the methods must be modified to handle the new type.
 *
 *	The internal variables if the GSRunLoopWatcher are used as follows -
 *
 *	The '_date' variable contains a date after which the event is useless
 *	and the watcher can be removed from the runloop.
 *
 *	If '_invalidated' is set, the watcher should be disabled and should
 *	be removed from the runloop when next encountered.
 *
 *	The 'data' variable is used to identify the  resource/event that the
 *	watcher is interested in.
 *
 *	The 'receiver' is the object which should be told when the event
 *	occurs.  This object is retained so that we know it will continue
 *	to exist and can handle a callback.
 *
 *	The 'type' variable indentifies the type of event watched for.
 *	NSRunLoops [-acceptInputForMode: beforeDate: ] method MUST contain
 *	code to watch for events of each type.
 *
 *	To set this variable, the method adding the GSRunLoopWatcher to the
 *	runloop must ask the 'receiver' (or its delegate) to supply a date
 *	using the '[-limitDateForMode: ]' message.
 *
 *	NB.  This class is private to NSRunLoop and must not be subclassed.
 */
 
static SEL	eventSel;	/* Initialized in [NSRunLoop +initialize] */

@interface GSRunLoopWatcher: NSObject
{
@public
  NSDate		*_date;		/* First to match layout of NSTimer */
  BOOL			_invalidated;	/* 2nd to match layout of NSTimer */
  IMP			handleEvent;	/* New-style event handling */
  void			*data;
  id			receiver;
  RunLoopEventType	type;
  unsigned 		count;
}
- (id) initWithType: (RunLoopEventType)type
	   receiver: (id)anObj
	       data: (void*)data;
@end

@implementation	GSRunLoopWatcher

- (void) dealloc
{
  RELEASE(_date);
  [super dealloc];
}

- (id) initWithType: (RunLoopEventType)aType
	   receiver: (id)anObj
	       data: (void*)item
{
  _invalidated = NO;

  switch (aType)
    {
      case ET_EDESC: 	type = aType;	break;
      case ET_RDESC: 	type = aType;	break;
      case ET_WDESC: 	type = aType;	break;
      case ET_RPORT: 	type = aType;	break;
      default: 
	[NSException raise: NSInvalidArgumentException
		    format: @"NSRunLoop - unknown event type"];
    }
  receiver = anObj;
  if ([receiver respondsToSelector: eventSel] == YES) 
    handleEvent = [receiver methodForSelector: eventSel];
  else
    [NSException raise: NSInvalidArgumentException
		format: @"RunLoop listener has no event handling method"];
  data = item;
  return self;
}

@end

/*
 *	Two optimisation functions that depend on a hack that the layout of
 *	the NSTimer class is known to be the same as GSRunLoopWatcher for the
 *	first two elements.
 */
static inline NSDate* timerDate(NSTimer* timer)
{
  return ((GSRunLoopWatcher*)timer)->_date;
}

static inline BOOL timerInvalidated(NSTimer* timer)
{
  return ((GSRunLoopWatcher*)timer)->_invalidated;
}



/*
 *	The GSRunLoopPerformer class is used to hold information about
 *	messages which are due to be sent to objects once each runloop
 *	iteration has passed.
 */
@interface GSRunLoopPerformer: NSObject
{
@public
  SEL		selector;
  id		target;
  id		argument;
  unsigned	order;
}

- (void) fire;
- (id) initWithSelector: (SEL)aSelector
		 target: (id)target
	       argument: (id)argument
		  order: (unsigned int)order;
@end

@implementation GSRunLoopPerformer

- (void) fire
{
  [target performSelector: selector withObject: argument];
}

- (id) initWithSelector: (SEL)aSelector
		 target: (id)aTarget
	       argument: (id)anArgument
		  order: (unsigned int)theOrder
{
  self = [super init];
  if (self)
    {
      selector = aSelector;
      target = aTarget;
      argument = anArgument;
      order = theOrder;
    }
  return self;
}

@end



@interface NSRunLoop (TimedPerformers)
- (NSMutableArray*) _timedPerformers;
@end

@implementation	NSRunLoop (TimedPerformers)
- (NSMutableArray*) _timedPerformers
{
  return _timedPerformers;
}
@end

/*
 * The GSTimedPerformer class is used to hold information about
 * messages which are due to be sent to objects at a particular time.
 */
@interface GSTimedPerformer: NSObject <GCFinalization>
{
@public
  SEL		selector;
  id		target;
  id		argument;
  NSTimer	*timer;
}

- (void) fire;
- (id) initWithSelector: (SEL)aSelector
		 target: (id)target
	       argument: (id)argument
		  delay: (NSTimeInterval)delay;
@end

@implementation GSTimedPerformer

- (void) dealloc
{
  [self gcFinalize];
  TEST_RELEASE(timer);
  RELEASE(target);
  RELEASE(argument);
  [super dealloc];
}

- (void) fire
{
  DESTROY(timer);
  [target performSelector: selector withObject: argument];
  [[[NSRunLoop currentRunLoop] _timedPerformers]
    removeObjectIdenticalTo: self];
}

- (void) gcFinalize
{
  if (timer != nil)
    {
      [timer invalidate];
    }
}

- (id) initWithSelector: (SEL)aSelector
		 target: (id)aTarget
	       argument: (id)anArgument
		  delay: (NSTimeInterval)delay
{
  self = [super init];
  if (self != nil)
    {
      selector = aSelector;
      target = RETAIN(aTarget);
      argument = RETAIN(anArgument);
      timer = [[NSTimer allocWithZone: NSDefaultMallocZone()]
	initWithTimeInterval: delay
	  targetOrInvocation: self
		    selector: @selector(fire)
		    userInfo: nil
		     repeats: NO];
    }
  return self;
}
@end



/*
 *      Setup for inline operation of arrays.
 */

#define GSI_ARRAY_TYPES       GSUNION_OBJ

#if	GS_WITH_GC == 0
#define GSI_ARRAY_RELEASE(A, X)	[(X).obj release]
#define GSI_ARRAY_RETAIN(A, X)	[(X).obj retain]
#else
#define GSI_ARRAY_RELEASE(A, X)	
#define GSI_ARRAY_RETAIN(A, X)	
#endif

#include <base/GSIArray.h>

static NSComparisonResult aSort(GSIArrayItem i0, GSIArrayItem i1)
{
  return [((GSRunLoopWatcher *)(i0.obj))->_date 
    compare: ((GSRunLoopWatcher *)(i1.obj))->_date];
}

#if	GS_WITH_GC == 0
static SEL	wRelSel;
static SEL	wRetSel;
static IMP	wRelImp;
static IMP	wRetImp;

static void
wRelease(NSMapTable* t, const void* w)
{
  (*wRelImp)((id)w, wRelSel);
}

static void
wRetain(NSMapTable* t, const void* w)
{
  (*wRetImp)((id)w, wRetSel);
}

const NSMapTableValueCallBacks WatcherMapValueCallBacks = 
{
  wRetain,
  wRelease,
  0
};
#else
#define	WatcherMapValueCallBacks	NSOwnedPointerMapValueCallBacks 
#endif

static void
aRetain(NSMapTable* t, const void* a)
{
}

static void
aRelease(NSMapTable* t, const void* a)
{
  GSIArrayEmpty((GSIArray)a);
  NSZoneFree(((GSIArray)a)->zone, (void*)a);
}

const NSMapTableValueCallBacks ArrayMapValueCallBacks = 
{
  aRetain,
  aRelease,
  0
};



/**
 * The GSRunLoopCtxt stores context information to handle polling for
 * events.  This information is associated with a particular runloop
 * mode, and persists throughout the life of the runloop instance.
 *
 *	NB.  This class is private to NSRunLoop and must not be subclassed.
 */
@interface	GSRunLoopCtxt : NSObject
{
@public
  void		*extra;		/** Copy of the RunLoop ivar.		*/
  NSString	*mode;		/** The mode for this context.		*/
  GSIArray	performers;	/** The actions to perform regularly.	*/
  GSIArray	timers;		/** The timers set for the runloop mode */
  GSIArray	watchers;	/** The inputs set for the runloop mode */
@private
  NSMapTable	*_efdMap;
  NSMapTable	*_rfdMap;
  NSMapTable	*_wfdMap;
  int		fairStart;	// For trying to ensure fair handling.
  BOOL		completed;	// To mark operation as completed.
#ifdef	HAVE_POLL
  int		pollfds_capacity;
  int		pollfds_count;
  struct pollfd	*pollfds;
#endif
}
- (void) endEvent: (void*)data
             type: (RunLoopEventType)type;
- (void) endPoll;
- (id) initWithMode: (NSString*)theMode extra: (void*)e;
- (BOOL) pollUntil: (int)milliseconds within: (NSArray*)contexts;
@end

@implementation	GSRunLoopCtxt
- (void) dealloc
{
  RELEASE(mode);
  GSIArrayEmpty(performers);
  NSZoneFree(performers->zone, (void*)performers);
  GSIArrayEmpty(timers);
  NSZoneFree(timers->zone, (void*)timers);
  GSIArrayEmpty(watchers);
  NSZoneFree(watchers->zone, (void*)watchers);
  if (_efdMap != 0)
    {
      NSFreeMapTable(_efdMap);
    }
  if (_rfdMap != 0)
    {
      NSFreeMapTable(_rfdMap);
    }
  if (_wfdMap != 0)
    {
      NSFreeMapTable(_wfdMap);
    }
#ifdef	HAVE_POLL
  if (pollfds != 0)
    {
      objc_free(pollfds);
    }
#endif
  [super dealloc];
}

/**
 * Remove any callback for the specified event which is set for an
 * uncompleted poll operation.<br />
 * This is called by nested event loops on contexts in outer loops
 * when they handle an event ... removing the event from the outer
 * loop ensures that it won't get handled twice, once by the inner
 * loop and once by the outer one.
 */
- (void) endEvent: (void*)data
             type: (RunLoopEventType)type
{
  if (completed == NO)
    {
      switch (type)
	{
	  case ET_RDESC: 
	    NSMapRemove(_rfdMap, data);
	    break;
	  case ET_WDESC: 
	    NSMapRemove(_wfdMap, data);
	    break;
	  case ET_EDESC: 
	    NSMapRemove(_efdMap, data);
	    break;
	  default:
	    NSLog(@"Ending an event of unkown type (%d)", type);
	    break;
	}
    }
}

/**
 * Mark this poll conext as having completed, so that if we are
 * executing a re-entrant poll, the enclosing poll operations
 * know they can stop what they are doing because an inner
 * operation has done the job.
 */
- (void) endPoll
{
  completed = YES;
}

- (id) init
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"-init may not be called for GSRunLoopCtxt"];
  return nil;
}

- (id) initWithMode: (NSString*)theMode extra: (void*)e
{
  self = [super init];
  if (self != nil)
    {
      NSZone	*z = [self zone];

      mode = [theMode copy];
      extra = e;
      performers = NSZoneMalloc(z, sizeof(GSIArray_t));
      GSIArrayInitWithZoneAndCapacity(performers, z, 8);
      timers = NSZoneMalloc(z, sizeof(GSIArray_t));
      GSIArrayInitWithZoneAndCapacity(timers, z, 8);
      watchers = NSZoneMalloc(z, sizeof(GSIArray_t));
      GSIArrayInitWithZoneAndCapacity(watchers, z, 8);

      _efdMap = NSCreateMapTable (NSIntMapKeyCallBacks,
				      WatcherMapValueCallBacks, 0);
      _rfdMap = NSCreateMapTable (NSIntMapKeyCallBacks,
				      WatcherMapValueCallBacks, 0);
      _wfdMap = NSCreateMapTable (NSIntMapKeyCallBacks,
				      WatcherMapValueCallBacks, 0);
    }
  return self;
}

#ifdef	HAVE_POLL

static void setPollfd(int fd, int event, GSRunLoopCtxt *ctxt)
{
  int		index;
  struct pollfd *pollfds = ctxt->pollfds;
  pollextra	*pe = (pollextra*)ctxt->extra;

  if (fd >= pe->limit)
    {
      int oldfd_limit = pe->limit;

      pe->limit = fd + 1;
      if (pe->index == 0)
	{
	  pe->index = objc_malloc(pe->limit * sizeof(*(pe->index)));
	}
      else
	{
	  pe->index = objc_realloc(pe->index, pe->limit * sizeof(*(pe->index)));
	}
      do
	{
	  pe->index[oldfd_limit++] = -1;
	}
      while (oldfd_limit < pe->limit);
    }
  index = pe->index[fd];
  if (index == -1)
    {
      if (ctxt->pollfds_count >= ctxt->pollfds_capacity)
	{
	  ctxt->pollfds_capacity += 8;
	  pollfds =
	    objc_realloc(pollfds, ctxt->pollfds_capacity * sizeof (*pollfds));
	  ctxt->pollfds = pollfds;
	}
      index = ctxt->pollfds_count++;
      pe->index[fd] = index;
      pollfds[index].fd = fd;
      pollfds[index].events = 0;
      pollfds[index].revents = 0;
    }
  pollfds[index].events |= event;
}

/**
 * Perform a poll for the specified runloop context.
 * If the method has been called re-entrantly, the contexts stack
 * will list all the contexts with polls in progress
 * and this method must tell those outer contexts not to handle events
 * which are handled by this context.
 */
- (BOOL) pollUntil: (int)milliseconds within: (NSArray*)contexts
{
  int		poll_return;
  int		fdEnd = 0;	/* Number of descriptors being monitored. */
  int		fdIndex;
  int		fdFinish;
  unsigned	i;

  i = GSIArrayCount(watchers);

  /*
   * Get ready to listen to file descriptors.
   * The maps will not have been emptied by any previous call.
   */
  NSResetMapTable(_efdMap);
  NSResetMapTable(_rfdMap);
  NSResetMapTable(_wfdMap);

  /*
   * Do the pre-listening set-up for the file descriptors of this mode.
   */
  if (pollfds_capacity < i + 1)
    {
      pollfds_capacity = i + 1;
      if (pollfds == 0)
	{
	  pollfds = objc_malloc(pollfds_capacity * sizeof(*pollfds));
	}
      else
	{
	  pollfds = objc_realloc(pollfds, pollfds_capacity * sizeof(*pollfds));
	}
    }
  pollfds_count = 0;
  ((pollextra*)extra)->limit = 0;

  while (i-- > 0)
    {
      GSRunLoopWatcher	*info;
      int		fd;

      info = GSIArrayItemAtIndex(watchers, i).obj;
      if (info->_invalidated == YES)
	{
	  GSIArrayRemoveItemAtIndex(watchers, i);
	  continue;
	}

      switch (info->type)
	{
	  case ET_EDESC: 
	    fd = (int)info->data;
	    setPollfd(fd, POLLPRI, self);
	    NSMapInsert(_efdMap, (void*)fd, info);
	    fdEnd++;
	    break;

	  case ET_RDESC: 
	    fd = (int)info->data;
	    setPollfd(fd, POLLIN, self);
	    NSMapInsert(_rfdMap, (void*)fd, info);
	    fdEnd++;
	    break;

	  case ET_WDESC: 
	    fd = (int)info->data;
	    setPollfd(fd, POLLOUT, self);
	    NSMapInsert(_wfdMap, (void*)fd, info);
	    fdEnd++;
	    break;

	  case ET_RPORT: 
	    if ([info->receiver isValid] == NO)
	      {
		/*
		 * We must remove an invalidated port.
		 */
		info->_invalidated = YES;
		GSIArrayRemoveItemAtIndex(watchers, i);
	      }
	    else
	      {
		id port = info->receiver;
		int port_fd_count = 128; // FIXME 
		int port_fd_array[port_fd_count];

		if ([port respondsToSelector:
		  @selector(getFds:count:)])
		  {
		    [port getFds: port_fd_array
			   count: &port_fd_count];
		  }
		NSDebugMLLog(@"NSRunLoop",
		  @"listening to %d port handles\n", port_fd_count);
		while (port_fd_count--)
		  {
		    fd = port_fd_array[port_fd_count];
		    setPollfd(fd, POLLIN, self);
		    NSMapInsert(_rfdMap, 
		      (void*)port_fd_array[port_fd_count], info);
		    fdEnd++;
		  }
	      }
	    break;
	}
    }

  /*
   * If there are notifications in the 'idle' queue, we try an
   * instantaneous select so that, if there is no input pending,
   * we can service the queue.  Similarly, if a task has completed,
   * we need to deliver its notifications.
   */
  if (GSCheckTasks() || GSNotifyMore())
    {
      milliseconds = 0;
    }

if (0) {
  int i;
  fprintf(stderr, "poll %d %d:", milliseconds, pollfds_count);
  for (i = 0; i < pollfds_count; i++)
    fprintf(stderr, " %d,%x", pollfds[i].fd, pollfds[i].events);
  fprintf(stderr, "\n");
}
  poll_return = poll (pollfds, pollfds_count, milliseconds);
if (0) {
  int i;
  fprintf(stderr, "ret %d %d:", poll_return, pollfds_count);
  for (i = 0; i < pollfds_count; i++)
    fprintf(stderr, " %d,%x", pollfds[i].fd, pollfds[i].revents);
  fprintf(stderr, "\n");
}

  NSDebugMLLog(@"NSRunLoop", @"poll returned %d\n", poll_return);

  if (poll_return < 0)
    {
      if (errno == EINTR)
	{
	  GSCheckTasks();
	  poll_return = 0;
	}
#ifdef __MINGW__
      else if (errno == 0)
	{
	  /* MinGW often returns an errno == 0. Not sure why */
	  poll_return = 0;
	}
#endif
      else
	{
	  /* Some exceptional condition happened. */
	  /* xxx We can do something with exception_fds, instead of
	     aborting here. */
	  NSLog (@"poll() error in -acceptInputForMode:beforeDate: '%s'",
	    GSLastErrorStr(errno));
	  abort ();
	}
    }

  if (poll_return == 0)
    {
      completed = YES;
      return NO;
    }

  /*
   * Look at all the file descriptors select() says are ready for action;
   * notify the corresponding object for each of the ready fd's.
   * NB. It is possible for a watcher to be missing from the map - if
   * the event handler of a previous watcher has 'run' the loop again
   * before returning.
   * NB. Each time this loop is entered, the starting position (fairStart)
   * is incremented - this is to ensure a fair distribion over all
   * inputs where multiple inputs are in use.  Note - fairStart can be
   * modified while we are in the loop (by recursive calls).
   */
  if (++fairStart >= fdEnd)
    {
      fairStart = 0;
      fdIndex = 0;
      fdFinish = 0;
    }
  else
    {
      fdIndex = fairStart;
      fdFinish = fairStart;
    }
  completed = NO;
  while (completed == NO)
    {
      if (pollfds[fdIndex].revents != 0)
	{
	  int			fd = pollfds[fdIndex].fd;
	  GSRunLoopWatcher	*watcher;
	  BOOL			found = NO;
	  
	  /*
	   * The poll() call supports various error conditions - all
	   * errors should be handled by any available handler.
	   * The ET_EDSEC handler is the primary handler for exceptions
	   * though it is more generally used to deal with out-of-band data.
	   */
	  if (pollfds[fdIndex].revents & (POLLPRI|POLLERR|POLLHUP|POLLNVAL))
	    {
	      watcher = (GSRunLoopWatcher*)NSMapGet(_efdMap,
		(void*)fd);
	      if (watcher != nil && watcher->_invalidated == NO)
		{
		  /*
		   * The watcher is still valid - so call its
		   * receivers event handling method.
		   */
		  (*watcher->handleEvent)(watcher->receiver,
		    eventSel, watcher->data, watcher->type,
		    (void*)(gsaddr)fd, mode);
		  i = [contexts count];
		  while (i-- > 0)
		    {
		      GSRunLoopCtxt	*c = [contexts objectAtIndex: i];

		      if (c != self) [c endEvent: (void*)fd type: ET_EDESC];
		    }
		}
	      GSNotifyASAP();
	      if (completed == YES)
		{
		  break;	// A nested poll has done the job.
		}
	      found = YES;
	    }
	  if (pollfds[fdIndex].revents & (POLLOUT|POLLERR|POLLHUP|POLLNVAL))
	    {
	      watcher = (GSRunLoopWatcher*)NSMapGet(_wfdMap,
		(void*)fd);
	      if (watcher != nil && watcher->_invalidated == NO)
		{
		  /*
		   * The watcher is still valid - so call its
		   * receivers event handling method.
		   */
		  (*watcher->handleEvent)(watcher->receiver,
		    eventSel, watcher->data, watcher->type,
		    (void*)(gsaddr)fd, mode);
		  i = [contexts count];
		  while (i-- > 0)
		    {
		      GSRunLoopCtxt	*c = [contexts objectAtIndex: i];

		      if (c != self) [c endEvent: (void*)fd type: ET_WDESC];
		    }
		}
	      GSNotifyASAP();
	      if (completed == YES)
		{
		  break;	// A nested poll has done the job.
		}
	      found = YES;
	    }
	  if (pollfds[fdIndex].revents & (POLLIN|POLLERR|POLLHUP|POLLNVAL))
	    {
	      watcher = (GSRunLoopWatcher*)NSMapGet(_rfdMap,
		(void*)fd);
	      if (watcher != nil && watcher->_invalidated == NO)
		{
		  /*
		   * The watcher is still valid - so call its
		   * receivers event handling method.
		   */
		  (*watcher->handleEvent)(watcher->receiver,
		    eventSel, watcher->data, watcher->type,
		    (void*)(gsaddr)fd, mode);
		  i = [contexts count];
		  while (i-- > 0)
		    {
		      GSRunLoopCtxt	*c = [contexts objectAtIndex: i];

		      if (c != self) [c endEvent: (void*)fd type: ET_RDESC];
		    }
		}
	      GSNotifyASAP();
	      if (completed == YES)
		{
		  break;	// A nested poll has done the job.
		}
	      found = YES;
	    }
	  if (found == YES && --poll_return == 0)
	    {
	      completed = YES;
	    }  
	}
      if (++fdIndex >= fdEnd)
	{
	  fdIndex = 0;
	}
      if (fdIndex == fdFinish)
	{
	  completed = YES;
	}
    }
  completed = YES;
  return YES;
}

#else

- (BOOL) pollUntil: (int)milliseconds within: (NSArray*)contexts
{
  struct timeval	timeout;
  void			*select_timeout;
  int			select_return;
  int			fdIndex;
  int			fdFinish;
  fd_set 		read_fds;	// Mask for read-ready fds.
  fd_set 		exception_fds;	// Mask for exception fds.
  fd_set 		write_fds;	// Mask for write-ready fds.
  int			num_inputs = 0;
  int			fdEnd = -1;
  unsigned		i;

  i = GSIArrayCount(watchers);

  /* Find out how much time we should wait, and set SELECT_TIMEOUT. */
  if (milliseconds == 0)
    {
      /* Don't wait at all. */
      timeout.tv_sec = 0;
      timeout.tv_usec = 0;
      select_timeout = &timeout;
    }
  else if (milliseconds > 0)
    {
      timeout.tv_sec = milliseconds/1000;
      timeout.tv_usec = (milliseconds - 1000 * timeout.tv_sec) * 1000;
      select_timeout = &timeout;
    }
  else 
    {
      timeout.tv_sec = -1;
      timeout.tv_usec = -1;
      select_timeout = NULL;
    }

  /*
   * Get ready to listen to file descriptors.
   * Initialize the set of FDS we'll pass to select(), and make sure we
   * have empty maps for keeping track of which watcher is associated
   * with which file descriptor.
   * The maps may not have been emptied if a previous call to this
   * method was terminated by an exception.
   */
  memset(&exception_fds, '\0', sizeof(exception_fds));
  memset(&read_fds, '\0', sizeof(read_fds));
  memset(&write_fds, '\0', sizeof(write_fds));
  NSResetMapTable(_efdMap);
  NSResetMapTable(_rfdMap);
  NSResetMapTable(_wfdMap);

  while (i-- > 0)
    {
      GSRunLoopWatcher	*info;
      int		fd;

      info = GSIArrayItemAtIndex(watchers, i).obj;
      if (info->_invalidated == YES)
	{
	  GSIArrayRemoveItemAtIndex(watchers, i);
	  continue;
	}
      switch (info->type)
	{
	  case ET_EDESC: 
	    fd = (int)info->data;
	    if (fd > fdEnd)
	      fdEnd = fd;
	    FD_SET (fd, &exception_fds);
	    NSMapInsert(_efdMap, (void*)fd, info);
	    num_inputs++;
	    break;

	  case ET_RDESC: 
	    fd = (int)info->data;
	    if (fd > fdEnd)
	      fdEnd = fd;
	    FD_SET (fd, &read_fds);
	    NSMapInsert(_rfdMap, (void*)fd, info);
	    num_inputs++;
	    break;

	  case ET_WDESC: 
	    fd = (int)info->data;
	    if (fd > fdEnd)
	      fdEnd = fd;
	    FD_SET (fd, &write_fds);
	    NSMapInsert(_wfdMap, (void*)fd, info);
	    num_inputs++;
	    break;

	  case ET_RPORT: 
	    if ([info->receiver isValid] == NO)
	      {
		/*
		 * We must remove an invalidated port.
		 */
		info->_invalidated = YES;
		GSIArrayRemoveItemAtIndex(watchers, i);
	      }
	    else
	      {
		id port = info->receiver;
		int port_fd_count = 128; // xxx #define this constant
		int port_fd_array[port_fd_count];

		if ([port respondsToSelector:
		  @selector(getFds:count:)])
		  {
		    [port getFds: port_fd_array
			   count: &port_fd_count];
		  }
		NSDebugMLLog(@"NSRunLoop", @"listening to %d port sockets",
		  port_fd_count);
		while (port_fd_count--)
		  {
		    fd = port_fd_array[port_fd_count];
		    FD_SET (port_fd_array[port_fd_count], &read_fds);
		    if (fd > fdEnd)
		      fdEnd = fd;
		    NSMapInsert(_rfdMap, 
		      (void*)port_fd_array[port_fd_count], info);
		    num_inputs++;
		  }
	      }
	    break;
	}
    }
  fdEnd++;

  /*
   * If there are notifications in the 'idle' queue, we try an
   * instantaneous select so that, if there is no input pending,
   * we can service the queue.  Similarly, if a task has completed,
   * we need to deliver its notifications.
   */
  if (GSCheckTasks() || GSNotifyMore())
    {
      timeout.tv_sec = 0;
      timeout.tv_usec = 0;
      select_timeout = &timeout;
    }

  // NSDebugMLLog(@"NSRunLoop", @"select timeout %d,%d", timeout.tv_sec, timeout.tv_usec);

  select_return = select (fdEnd, &read_fds, &write_fds,
    &exception_fds, select_timeout);

  NSDebugMLLog(@"NSRunLoop", @"select returned %d", select_return);

  if (select_return < 0)
    {
      if (errno == EINTR)
	{
	  GSCheckTasks();
	  select_return = 0;
	}
#ifdef __MINGW__
      else if (errno == 0)
	{
	  /* MinGW often returns an errno == 0. Not sure why */
	    select_return = 0;
	}
#endif
      else
	{
	  /* Some exceptional condition happened. */
	  /* xxx We can do something with exception_fds, instead of
	     aborting here. */
	  NSLog (@"select() error in -acceptInputForMode:beforeDate: '%s'",
	    GSLastErrorStr(errno));
	  abort ();
	}
    }
  if (select_return == 0)
    {
      completed = YES;
      return NO;
    }
      
  /*
   * Look at all the file descriptors select() says are ready for action;
   * notify the corresponding object for each of the ready fd's.
   * NB. Each time this roop is entered, the starting position (fairStart)
   * is incremented - this is to ensure a fair distribtion over all
   * inputs where multiple inputs are in use.  Note - fairStart can be
   * modified while we are in the loop (by recursive calls).
   */
  if (++fairStart >= fdEnd)
    {
      fairStart = 0;
      fdIndex = 0;
      fdFinish = 0;
    }
  else
    {
      fdIndex = fairStart;
      fdFinish = fairStart;
    }
  completed = NO;
  while (completed == NO)
    {
      BOOL	found = NO;

      if (FD_ISSET (fdIndex, &exception_fds))
	{
	  GSRunLoopWatcher	*watcher;

	  watcher = (GSRunLoopWatcher*)NSMapGet(_efdMap,
	    (void*)fdIndex);
	  if (watcher != nil && watcher->_invalidated == NO)
	    {
	      /*
	       * The watcher is still valid - so call its receivers
	       * event handling method.
	       */
	      (*watcher->handleEvent)(watcher->receiver,
		eventSel, watcher->data, watcher->type,
		(void*)(gsaddr)fdIndex, mode);
	      i = [contexts count];
	      while (i-- > 0)
		{
		  GSRunLoopCtxt	*c = [contexts objectAtIndex: i];

		  if (c != self) [c endEvent: (void*)fdIndex type: ET_EDESC];
		}
	    }
	  GSNotifyASAP();
	  if (completed == YES)
	    {
	      break;
	    }
	  found = YES;
	}
      if (FD_ISSET (fdIndex, &write_fds))
	{
	  GSRunLoopWatcher	*watcher;

	  watcher = NSMapGet(_wfdMap, (void*)fdIndex);
	  if (watcher != nil && watcher->_invalidated == NO)
	    {
	      /*
	       * The watcher is still valid - so call its receivers
	       * event handling method.
	       */
	      (*watcher->handleEvent)(watcher->receiver,
		eventSel, watcher->data, watcher->type,
		(void*)(gsaddr)fdIndex, mode);
	      i = [contexts count];
	      while (i-- > 0)
		{
		  GSRunLoopCtxt	*c = [contexts objectAtIndex: i];

		  if (c != self) [c endEvent: (void*)fdIndex type: ET_WDESC];
		}
	    }
	  GSNotifyASAP();
	  if (completed == YES)
	    {
	      break;
	    }
	  found = YES;
	}
      if (FD_ISSET (fdIndex, &read_fds))
	{
	  GSRunLoopWatcher	*watcher;

	  watcher = (GSRunLoopWatcher*)NSMapGet(_rfdMap, (void*)fdIndex);
	  if (watcher != nil && watcher->_invalidated == NO)
	    {
	      /*
	       * The watcher is still valid - so call its receivers
	       * event handling method.
	       */
	      (*watcher->handleEvent)(watcher->receiver,
		eventSel, watcher->data, watcher->type,
		(void*)(gsaddr)fdIndex, mode);
	      i = [contexts count];
	      while (i-- > 0)
		{
		  GSRunLoopCtxt	*c = [contexts objectAtIndex: i];

		  if (c != self) [c endEvent: (void*)fdIndex type: ET_RDESC];
		}
	    }
	  GSNotifyASAP();
	  if (completed == YES)
	    {
	      break;
	    }
	  found = YES;
	}
      if (found == YES && --select_return == 0)
	{
	  completed = YES;
	}
      if (++fdIndex >= fdEnd)
	{
	  fdIndex = 0;
	}
      if (fdIndex == fdFinish)
	{
	  completed = YES;
	}
    }
  completed = YES;
  return YES;
}

#endif
@end



@implementation NSObject (TimedPerformers)

+ (void) cancelPreviousPerformRequestsWithTarget: (id)target
					selector: (SEL)aSelector
					  object: (id)arg
{
  NSMutableArray	*perf = [[NSRunLoop currentRunLoop] _timedPerformers];
  unsigned		count = [perf count];

  if (count > 0)
    {
      GSTimedPerformer	*array[count];

      IF_NO_GC(RETAIN(target));
      IF_NO_GC(RETAIN(arg));
      [perf getObjects: array];
      while (count-- > 0)
	{
	  GSTimedPerformer	*p = array[count];

	  if (p->target == target && sel_eq(p->selector, aSelector)
	    && [p->argument isEqual: arg])
	    {
	      [perf removeObjectAtIndex: count];
	    }
	}
      RELEASE(arg);
      RELEASE(target);
    }
}

- (void) performSelector: (SEL)aSelector
	      withObject: (id)argument
	      afterDelay: (NSTimeInterval)seconds
{
  NSRunLoop		*loop = [NSRunLoop currentRunLoop];
  GSTimedPerformer	*item;

  item = [[GSTimedPerformer alloc] initWithSelector: aSelector
					     target: self
					   argument: argument
					      delay: seconds];
  [[loop _timedPerformers] addObject: item];
  RELEASE(item);
  [loop addTimer: item->timer forMode: NSDefaultRunLoopMode];
}

- (void) performSelector: (SEL)aSelector
	      withObject: (id)argument
	      afterDelay: (NSTimeInterval)seconds
		 inModes: (NSArray*)modes
{
  unsigned	count = [modes count];

  if (count > 0)
    {
      NSRunLoop		*loop = [NSRunLoop currentRunLoop];
      NSString		*marray[count];
      GSTimedPerformer	*item;
      unsigned		i;

      item = [[GSTimedPerformer alloc] initWithSelector: aSelector
						 target: self
					       argument: argument
						  delay: seconds];
      [[loop _timedPerformers] addObject: item];
      RELEASE(item);
      [modes getObjects: marray];
      for (i = 0; i < count; i++)
	{
	  [loop addTimer: item->timer forMode: marray[i]];
	}
    }
}

@end



@interface NSRunLoop (Private)

- (void) _addWatcher: (GSRunLoopWatcher*)item
	     forMode: (NSString*)mode;
- (void) _checkPerformers: (GSRunLoopCtxt*)context;
- (GSRunLoopWatcher*) _getWatcher: (void*)data
			     type: (RunLoopEventType)type
			  forMode: (NSString*)mode;
- (void) _removeWatcher: (void*)data
		   type: (RunLoopEventType)type
		forMode: (NSString*)mode;

@end

@implementation NSRunLoop (Private)

/* Add a watcher to the list for the specified mode.  Keep the list in
   limit-date order. */
- (void) _addWatcher: (GSRunLoopWatcher*) item forMode: (NSString*)mode
{
  GSRunLoopCtxt	*context;
  GSIArray	watchers;
  id		obj;

  context = NSMapGet(_contextMap, mode);
  if (context == nil)
    {
      context = [[GSRunLoopCtxt alloc] initWithMode: mode extra: _extra];
      NSMapInsert(_contextMap, context->mode, context);
      RELEASE(context);
    }
  watchers = context->watchers;

  /*
   *	If the receiver or its delegate (if any) respond to
   *	'limitDateForMode: ' then we ask them for the limit date for
   *	this watcher.
   */
  obj = item->receiver;
  if ([obj respondsToSelector: @selector(limitDateForMode:)])
    {
      NSDate	*d = [obj limitDateForMode: mode];

      item->_date = RETAIN(d);
    }
  else if ([obj respondsToSelector: @selector(delegate)])
    {
      obj = [obj delegate];
      if (obj != nil && [obj respondsToSelector: @selector(limitDateForMode:)])
	{
	  NSDate	*d = [obj limitDateForMode: mode];

	  item->_date = RETAIN(d);
	}
      else
	item->_date = RETAIN(theFuture);
    }
  else
    item->_date = RETAIN(theFuture);
  GSIArrayInsertSorted(watchers, (GSIArrayItem)item, aSort);
}

- (void) _checkPerformers: (GSRunLoopCtxt*)context
{
  if (context != nil)
    {
      GSIArray	performers = context->performers;
      unsigned	count = GSIArrayCount(performers);

      if (count > 0)
	{
	  GSRunLoopPerformer	*array[count];
	  NSMapEnumerator	enumerator;
	  GSRunLoopCtxt		*context;
	  void			*mode;
	  unsigned		i;

	  /*
	   * Copy the array - because we have to cancel the requests
	   * before firing.
	   */
	  for (i = 0; i < count; i++)
	    {
	      array[i] = RETAIN(GSIArrayItemAtIndex(performers, i).obj);
	    }

	  /*
	   * Remove the requests that we are about to fire from all modes.
	   */
	  enumerator = NSEnumerateMapTable(_contextMap);
	  while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&context))
	    {
	      if (context != nil)
		{
		  GSIArray	performers = context->performers;
		  unsigned	tmpCount = GSIArrayCount(performers);

		  while (tmpCount--)
		    {
		      GSRunLoopPerformer	*p;

		      p = GSIArrayItemAtIndex(performers, tmpCount).obj;
		      for (i = 0; i < count; i++)
			{
			  if (p == array[i])
			    {
			      GSIArrayRemoveItemAtIndex(performers, tmpCount);
			    }
			}
		    }
		}
	    }

	  /*
	   * Finally, fire the requests.
	   */
	  for (i = 0; i < count; i++)
	    {
	      [array[i] fire];
	      RELEASE(array[i]);
	    }
	}
    }
}

/**
 * Locates a runloop watcher matching the specified data and type in this
 * runloop.  If the mode is nil, either the currentMode is used (if the
 * loop is running) or NSDefaultRunLoopMode is used.
 */
- (GSRunLoopWatcher*) _getWatcher: (void*)data
			     type: (RunLoopEventType)type
			  forMode: (NSString*)mode
{
  GSRunLoopCtxt	*context;

  if (mode == nil)
    {
      mode = [self currentMode];
      if (mode == nil)
	{
	  mode = NSDefaultRunLoopMode;
	}
    }

  context = NSMapGet(_contextMap, mode);
  if (context != nil)
    {
      GSIArray	watchers = context->watchers;
      unsigned	i = GSIArrayCount(watchers);

      while (i-- > 0)
	{
	  GSRunLoopWatcher	*info;

	  info = GSIArrayItemAtIndex(watchers, i).obj;
	  if (info->type == type && info->data == data)
	    {
	      return info;
	    }
	}
    }
  return nil;
}

/**
 * Removes a runloop watcher matching the specified data and type in this
 * runloop.  If the mode is nil, either the currentMode is used (if the
 * loop is running) or NSDefaultRunLoopMode is used.
 */
- (void) _removeWatcher: (void*)data
                   type: (RunLoopEventType)type
                forMode: (NSString*)mode
{
  GSRunLoopCtxt	*context;

  if (mode == nil)
    {
      mode = [self currentMode];
      if (mode == nil)
	{
	  mode = NSDefaultRunLoopMode;
	}
    }

  context = NSMapGet(_contextMap, mode);
  if (context != nil)
    {
      GSIArray	watchers = context->watchers;
      unsigned	i = GSIArrayCount(watchers);

      while (i-- > 0)
	{
	  GSRunLoopWatcher	*info;

	  info = GSIArrayItemAtIndex(watchers, i).obj;
	  if (info->type == type && info->data == data)
	    {
	      info->_invalidated = YES;
	      GSIArrayRemoveItemAtIndex(watchers, i);
	    }
	}
    }
}

@end


@implementation NSRunLoop(GNUstepExtensions)

/**
 * Adds a runloop watcher matching the specified data and type in this
 * runloop.  If the mode is nil, either the currentMode is used (if the
 * loop is running) or NSDefaultRunLoopMode is used.
 */
- (void) addEvent: (void*)data
             type: (RunLoopEventType)type
          watcher: (id<RunLoopEvents>)watcher
          forMode: (NSString*)mode
{
  GSRunLoopWatcher	*info;

  if (mode == nil)
    {
      mode = [self currentMode];
      if (mode == nil)
	{
	  mode = NSDefaultRunLoopMode;
	}
    }

  info = [self _getWatcher: data type: type forMode: mode];

  if (info && info->receiver == (id)watcher)
    {
      /* Increment usage count for this watcher. */
      info->count++;
    }
  else
    {
      /* Remove any existing handler for another watcher. */
      [self _removeWatcher: data type: type forMode: mode];

      /* Create new object to hold information. */
      info = [[GSRunLoopWatcher alloc] initWithType: type
					   receiver: watcher
					       data: data];
      /* Add the object to the array for the mode. */
      [self _addWatcher: info forMode: mode];
      RELEASE(info);		/* Now held in array.	*/
    }
}

/**
 * Removes a runloop watcher matching the specified data and type in this
 * runloop.  If the mode is nil, either the currentMode is used (if the
 * loop is running) or NSDefaultRunLoopMode is used.
 * The additional removeAll flag may be used to remove all instances of
 * the watcher rather than just a single one.
 */
- (void) removeEvent: (void*)data
                type: (RunLoopEventType)type
             forMode: (NSString*)mode
		 all: (BOOL)removeAll
{
  if (mode == nil)
    {
      mode = [self currentMode];
      if (mode == nil)
	{
	  mode = NSDefaultRunLoopMode;
	}
    }
  if (removeAll)
    {
      [self _removeWatcher: data type: type forMode: mode];
    }
  else
    {
      GSRunLoopWatcher	*info;

      info = [self _getWatcher: data type: type forMode: mode];
  
      if (info)
	{
	  if (info->count == 0)
	    {
	      [self _removeWatcher: data type: type forMode: mode];
  	    }
	  else
	    {
	      info->count--;
	    }
	}
    }
}

@end



@implementation NSRunLoop

+ (void) initialize
{
  if (self == [NSRunLoop class])
    {
      [self currentRunLoop];
      theFuture = RETAIN([NSDate distantFuture]);
      eventSel = @selector(receivedEvent:type:extra:forMode:);
#if	GS_WITH_GC == 0
      wRelSel = @selector(release);
      wRetSel = @selector(retain);
      wRelImp = [[GSRunLoopWatcher class] instanceMethodForSelector: wRelSel];
      wRetImp = [[GSRunLoopWatcher class] instanceMethodForSelector: wRetSel];
#endif
    }
}

+ (NSRunLoop*) currentRunLoop
{
  static NSString	*key = @"NSRunLoopThreadKey";
  NSMutableDictionary	*d;
  NSRunLoop		*r;

  d = GSCurrentThreadDictionary();
  r = [d objectForKey: key];
  if (r == nil)
    {
      if (d != nil)
	{
	  r = [self new];
	  [d setObject: r forKey: key];
	  RELEASE(r);
	}
    }
  return r;
}

/* This is the designated initializer. */
- (id) init
{
  self = [super init];
  if (self != nil)
    {
      _contextStack = [NSMutableArray new];
      _contextMap = NSCreateMapTable (NSNonRetainedObjectMapKeyCallBacks,
					 NSObjectMapValueCallBacks, 0);
      _timedPerformers = [[NSMutableArray alloc] initWithCapacity: 8];
#ifdef	HAVE_POLL
      _extra = objc_malloc(sizeof(pollextra));
      memset(_extra, '\0', sizeof(pollextra));
#endif
    }
  return self;
}

- (void) dealloc
{
  [self gcFinalize];
  [super dealloc];
}

- (void) gcFinalize
{
#ifdef	HAVE_POLL
  if (_extra != 0)
    {
      pollextra	*e = (pollextra*)_extra;

      if (e->index != 0)
	objc_free(e->index);
      objc_free(e);
    }
#endif
  RELEASE(_contextStack);
  if (_contextMap != 0)
    {
      NSFreeMapTable(_contextMap);
    }
  RELEASE(_timedPerformers);
}

/**
 * Returns the current mode of this runloop.  If the runloop is not running
 * then this method returns nil.
 */
- (NSString*) currentMode
{
  return _currentMode;
}


/* Adding timers.  They are removed when they are invalid. */

- (void) addTimer: (NSTimer*)timer
	  forMode: (NSString*)mode
{
  GSRunLoopCtxt	*context;
  GSIArray	timers;

  context = NSMapGet(_contextMap, mode);
  if (context == nil)
    {
      context = [[GSRunLoopCtxt alloc] initWithMode: mode extra: _extra];
      NSMapInsert(_contextMap, context->mode, context);
      RELEASE(context);
    }
  timers = context->timers;
  GSIArrayInsertSorted(timers, (GSIArrayItem)timer, aSort);
}


/**
 * Fire appropriate timers and determine the earliest time that anything
 * watched for becomes useless.
 */
- (NSDate*) limitDateForMode: (NSString*)mode
{
  GSRunLoopCtxt		*context = NSMapGet(_contextMap, mode);
  NSDate		*when = nil;

  if (context != nil)
    {
      NSTimer		*min_timer = nil;
      GSRunLoopWatcher	*min_watcher = nil;
      NSString		*savedMode = _currentMode;
      CREATE_AUTORELEASE_POOL(arp);

      _currentMode = mode;
      NS_DURING
	{
	  GSIArray	timers = context->timers;
	  GSIArray	watchers = context->watchers;

	  while (GSIArrayCount(timers) != 0)
	    {
	      min_timer = GSIArrayItemAtIndex(timers, 0).obj;
	      if (timerInvalidated(min_timer) == YES)
		{
		  GSIArrayRemoveItemAtIndex(timers, 0);
		  min_timer = nil;
		  continue;
		}

	      if ([timerDate(min_timer) timeIntervalSinceNow] > 0)
		{
		  break;
		}

	      GSIArrayRemoveItemAtIndexNoRelease(timers, 0);
	      /* Firing will also increment its fireDate, if it is repeating. */
	      [min_timer fire];
	      if (timerInvalidated(min_timer) == NO)
		{
		  GSIArrayInsertSortedNoRetain(timers,
		    (GSIArrayItem)min_timer, aSort);
		}
	      else
		{
		  RELEASE(min_timer);
		}
	      min_timer = nil;
	      GSNotifyASAP();		/* Post notifications. */
	    }

	  /* Is this right? At the moment we invalidate and discard watchers
	     whose limit-dates have passed. */
	  while (GSIArrayCount(watchers) != 0)
	    {
	      min_watcher = GSIArrayItemAtIndex(watchers, 0).obj;

	      if (min_watcher->_invalidated == YES)
		{
		  GSIArrayRemoveItemAtIndex(watchers, 0);
		  min_watcher = nil;
		  continue;
		}

	      if ([min_watcher->_date timeIntervalSinceNow] > 0)
		{
		  break;
		}
	      else
		{
		  id		obj;
		  NSDate	*nxt = nil;

		  /*
		   *	If the receiver or its delegate wants to know about
		   *	timeouts - inform it and give it a chance to set a
		   *	revised limit date.
		   */
		  GSIArrayRemoveItemAtIndexNoRelease(watchers, 0);
		  obj = min_watcher->receiver;
		  if ([obj respondsToSelector: 
		    @selector(timedOutEvent:type:forMode:)])
		    {
		      nxt = [obj timedOutEvent: min_watcher->data
					  type: min_watcher->type
				       forMode: mode];
		    }
		  else if ([obj respondsToSelector: @selector(delegate)])
		    {
		      obj = [obj delegate];
		      if (obj != nil && [obj respondsToSelector: 
			@selector(timedOutEvent:type:forMode:)])
			{
			  nxt = [obj timedOutEvent: min_watcher->data
					      type: min_watcher->type
					   forMode: mode];
			}
		    }
		  if (nxt && [nxt timeIntervalSinceNow] > 0.0)
		    {
		      /*
		       * If the watcher has been given a revised limit date -
		       * re-insert it into the queue in the correct place.
		       */
		      ASSIGN(min_watcher->_date, nxt);
		      GSIArrayInsertSortedNoRetain(watchers,
			(GSIArrayItem)min_watcher, aSort);
		    }
		  else
		    {
		      /*
		       * If the watcher is now useless - invalidate and
		       * release it.
		       */
		      min_watcher->_invalidated = YES;
		      RELEASE(min_watcher);
		    }
		  min_watcher = nil;
		}
	    }
	  _currentMode = savedMode;
	}
      NS_HANDLER
	{
	  _currentMode = savedMode;
	  [localException raise];
	}
      NS_ENDHANDLER

      RELEASE(arp);

      /*
       * If there are timers - set limit date to the earliest of them.
       * If there are watchers, set the limit date to that of the earliest
       * watcher (or leave it as the date of the earliest timer if that is
       * before the watchers limit).
       */
      if (min_timer != nil)
	{
	  when = timerDate(min_timer);
	  if (min_watcher != nil
	    && [min_watcher->_date compare: when] == NSOrderedAscending)
	    {
	      when = min_watcher->_date;
	    }
	}
      else if (min_watcher != nil)
	{
	  when = min_watcher->_date;
	}
      else
	{
	  return nil;	/* Nothing waiting to be done.	*/
	}

      NSDebugMLLog(@"NSRunLoop", @"limit date %f",
	[when timeIntervalSinceReferenceDate]);
    }
  return when;
}

/**
 * Listen to input sources.<br />
 * If limit_date is nil or in the past, then don't wait;
 * just poll inputs and return,
 * otherwise block until input is available or until the
 * earliest limit date has passed (whichever comes first).<br />
 * If the supplied mode is nil, uses NSDefaultRunLoopMode.
 */
- (void) acceptInputForMode: (NSString*)mode 
		 beforeDate: (NSDate*)limit_date
{
  GSRunLoopCtxt		*context;
  NSTimeInterval	ti;
  int			timeout_ms;
  NSString		*savedMode = _currentMode;
  CREATE_AUTORELEASE_POOL(arp);

  NSAssert(mode, NSInvalidArgumentException);
  if (mode == nil)
    {
      mode = NSDefaultRunLoopMode;
    }
  _currentMode = mode;
  context = NSMapGet(_contextMap, mode);

  [self _checkPerformers: context];

  NS_DURING
    {
      GSIArray		watchers;
      unsigned		i;

      if (context == nil || (watchers = context->watchers) == 0
	|| (i = GSIArrayCount(watchers)) == 0)
	{
	  NSDebugMLLog(@"NSRunLoop", @"no inputs in mode %@", mode);
	  GSNotifyASAP();
	  GSNotifyIdle();
	  ti = [limit_date timeIntervalSinceNow];
	  /*
	   * Pause for as long as possible (up to the limit date)
	   */
	  if (ti > 0.0)
	    {
#if	defined(HAVE_USLEEP)
	      if (ti >= INT_MAX / 1000000)
		{
		  ti = INT_MAX;
		}
	      else
		{
		  ti *= 1000000;
		}
	      usleep (ti);
#elif	defined(__MINGW__)
	      if (ti >= INT_MAX / 1000)
		{
		  ti = INT_MAX;
		}
	      else
		{
		  ti *= 1000;
		}
	      Sleep (ti);
#else
	      sleep (ti);
#endif
	    }
	  GSCheckTasks();
	  if (context != nil)
	    {
	      [self _checkPerformers: context];
	    }
	  GSNotifyASAP();
	  _currentMode = savedMode;
	  RELEASE(arp);
	  NS_VOIDRETURN;
	}

      /* Find out how much time we should wait, and set SELECT_TIMEOUT. */
      if (!limit_date)
	{
	  /* Don't wait at all. */
	  timeout_ms = 0;
	}
      else if ((ti = [limit_date timeIntervalSinceNow]) > 0.0)
	{
	  /* Wait until the LIMIT_DATE. */
	  NSDebugMLLog(@"NSRunLoop", @"accept I/P before %f (sec from now %f)", 
	    [limit_date timeIntervalSinceReferenceDate], ti);
	  if (ti >= INT_MAX / 1000)
	    {
	      timeout_ms = INT_MAX;	// Far future.
	    }
	  else
	    {
	      timeout_ms = ti * 1000;
	    }
	}
      else if (ti <= 0.0)
	{
	  /* The LIMIT_DATE has already past; return immediately without
	     polling any inputs. */
	  GSCheckTasks();
	  [self _checkPerformers: context];
	  GSNotifyASAP();
	  NSDebugMLLog(@"NSRunLoop", @"limit date past, returning");
	  _currentMode = savedMode;
	  RELEASE(arp);
	  NS_VOIDRETURN;
	}
      else
	{
	  /* Wait forever. */
	  NSDebugMLLog(@"NSRunLoop", @"accept input waiting forever");
	  timeout_ms = -1;
	}

      if ([_contextStack indexOfObjectIdenticalTo: context] == NSNotFound)
	{
	  [_contextStack addObject: context];
	}
      if ([context pollUntil: timeout_ms within: _contextStack] == NO)
	{
	  GSNotifyIdle();
	}
      [self _checkPerformers: context];
      GSNotifyASAP();
      _currentMode = savedMode;
      /*
       * Once a poll has been completed on a context, we can remove that
       * context from the stack even if it actually polling at an outer
       * level of re-entrancy ... since the poll we have just done will
       * have handled any events that the outer levels would have wanted
       * to handle, and the polling for this context will be marked as ended.
       */
      [context endPoll];
      [_contextStack removeObjectIdenticalTo: context];
    }
  NS_HANDLER
    {
      _currentMode = savedMode;
      [context endPoll];
      [_contextStack removeObjectIdenticalTo: context];
      [localException raise];
    }
  NS_ENDHANDLER
  RELEASE(arp);
}

/**
 * Calls -acceptInputForMode:beforeDate: to run the loop once.<br />
 * If the limit dates for all of mode's input sources have passed,
 * returns NO without running the loop, otherwise returns YES.
 */
- (BOOL) runMode: (NSString*)mode beforeDate: (NSDate*)date
{
  id	d;

  NSAssert(mode && date, NSInvalidArgumentException);
  /* If date has already passed, simply return. */
  if ([date timeIntervalSinceNow] < 0)
    {
      NSDebugMLLog(@"NSRunLoop", @"run mode with date already past");
      /*
       * Notify if any tasks have completed.
       */
      if (GSCheckTasks() == YES)
	{
	  GSNotifyASAP();
	}
      return NO;
    }

  /* Find out how long we can wait before first limit date. */
  d = [self limitDateForMode: mode];
  if (d == nil)
    {
      NSDebugMLLog(@"NSRunLoop", @"run mode with nothing to do");
      /*
       * Notify if any tasks have completed.
       */
      if (GSCheckTasks() == YES)
	{
	  GSNotifyASAP();
	}
      return NO;
    }

  /*
   * Use the earlier of the two dates we have.
   * Retain the date in case the firing of a timer (or some other event)
   * releases it.
   */
  d = [d earlierDate: date];
  IF_NO_GC(RETAIN(d));

  /* Wait, listening to our input sources. */
  [self acceptInputForMode: mode beforeDate: d];

  RELEASE(d);

  return YES;
}

- (void) run
{
  [self runUntilDate: theFuture];
}

- (void) runUntilDate: (NSDate*)date
{
  double	ti = [date timeIntervalSinceNow];
  BOOL		mayDoMore = YES;

  /* Positive values are in the future. */
  while (ti > 0 && mayDoMore == YES)
    {
      NSDebugMLLog(@"NSRunLoop", @"run until date %f seconds from now", ti);
      mayDoMore = [self runMode: NSDefaultRunLoopMode beforeDate: date];
      ti = [date timeIntervalSinceNow];
    }
}

@end



@implementation	NSRunLoop (OPENSTEP)

- (void) addPort: (NSPort*)port
         forMode: (NSString*)mode
{
  return [self addEvent: (void*)port
		   type: ET_RPORT
		watcher: (id<RunLoopEvents>)port
		forMode: (NSString*)mode];
}

- (void) cancelPerformSelector: (SEL)aSelector
			target: (id) target
		      argument: (id) argument
{
  NSMapEnumerator	enumerator;
  GSRunLoopCtxt		*context;
  void			*mode;

  enumerator = NSEnumerateMapTable(_contextMap);

  while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&context))
    {
      if (context != nil)
	{
	  GSIArray	performers = context->performers;
	  unsigned	count = GSIArrayCount(performers);

	  while (count--)
	    {
	      GSRunLoopPerformer	*p;

	      p = GSIArrayItemAtIndex(performers, count).obj;
	      if (p->target == target && sel_eq(p->selector, aSelector)
		&& p->argument == argument)
		{
		  GSIArrayRemoveItemAtIndex(performers, count);
		}
	    }
	}
    }
}

- (void) configureAsServer
{
/* Nothing to do here */
}

- (void) performSelector: (SEL)aSelector
		  target: (id)target
		argument: (id)argument
		   order: (unsigned int)order
		   modes: (NSArray*)modes
{
  unsigned		count = [modes count];

  if (count > 0)
    {
      NSString			*array[count];
      GSRunLoopPerformer	*item;

      item = [[GSRunLoopPerformer alloc] initWithSelector: aSelector
						   target: target
						 argument: argument
						    order: order];

      [modes getObjects: array];
      while (count-- > 0)
	{
	  NSString	*mode = array[count];
	  unsigned	end;
	  unsigned	i;
	  GSRunLoopCtxt	*context;
	  GSIArray	performers;

	  context = NSMapGet(_contextMap, mode);
	  if (context == nil)
	    {
	      context = [[GSRunLoopCtxt alloc] initWithMode: mode
						      extra: _extra];
	      NSMapInsert(_contextMap, context->mode, context);
	      RELEASE(context);
	    }
	  performers = context->performers;

	  end = GSIArrayCount(performers);
	  for (i = 0; i < end; i++)
	    {
	      GSRunLoopPerformer	*p;

	      p = GSIArrayItemAtIndex(performers, i).obj;
	      if (p->order <= order)
		{
		  GSIArrayInsertItem(performers, (GSIArrayItem)item, i);
		  break;
		}
	    }
	  if (i == end)
	    {
	      GSIArrayInsertItem(performers, (GSIArrayItem)item, i);
	    }
	}
      RELEASE(item);
    }
}

- (void) removePort: (NSPort*)port
            forMode: (NSString*)mode
{
  return [self removeEvent: (void*)port type: ET_RPORT forMode: mode all: NO];
}

@end


/**
 * The GSRunLoopCtxt stores context information to handle polling for
 * events.  This information is associated with a particular runloop
 * mode, and persists throughout the life of the runloop instance.
 *
 *	NB.  This class is private to NSRunLoop and must not be subclassed.
 */

#include "config.h"

#include "GNUstepBase/preface.h"
#include "GNUstepBase/GSRunLoopCtxt.h"
#include "GNUstepBase/GSRunLoopWatcher.h"
#include <Foundation/NSDebug.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSPort.h>

#ifdef HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif
#ifdef HAVE_POLL_F
#include <poll.h>
#endif
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

extern BOOL	GSCheckTasks();

#if	GS_WITH_GC == 0
SEL	wRelSel;
SEL	wRetSel;
IMP	wRelImp;
IMP	wRetImp;

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
#else
#define	WatcherMapValueCallBacks	NSOwnedPointerMapValueCallBacks 
#endif

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
#ifdef	HAVE_POLL_F
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
 * Mark this poll context as having completed, so that if we are
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

#ifdef	HAVE_POLL_F

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
  int		fdEnd;	/* Number of descriptors being monitored. */
  int		fdIndex;
  int		fdFinish;
  unsigned int	i;

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
	  continue;
	}

      switch (info->type)
	{
	  case ET_EDESC: 
	    fd = (int)info->data;
	    setPollfd(fd, POLLPRI, self);
	    NSMapInsert(_efdMap, (void*)fd, info);
	    break;

	  case ET_RDESC: 
	    fd = (int)info->data;
	    setPollfd(fd, POLLIN, self);
	    NSMapInsert(_rfdMap, (void*)fd, info);
	    break;

	  case ET_WDESC: 
	    fd = (int)info->data;
	    setPollfd(fd, POLLOUT, self);
	    NSMapInsert(_wfdMap, (void*)fd, info);
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

#if 0
{
  unsigned int i;
  fprintf(stderr, "poll %d %d:", milliseconds, pollfds_count);
  for (i = 0; i < pollfds_count; i++)
    fprintf(stderr, " %d,%x", pollfds[i].fd, pollfds[i].events);
  fprintf(stderr, "\n");
}
#endif
  poll_return = poll (pollfds, pollfds_count, milliseconds);
#if 0
{
  unsigned int i;
  fprintf(stderr, "ret %d %d:", poll_return, pollfds_count);
  for (i = 0; i < pollfds_count; i++)
    fprintf(stderr, " %d,%x", pollfds[i].fd, pollfds[i].revents);
  fprintf(stderr, "\n");
}
#endif

  NSDebugMLLog(@"NSRunLoop", @"poll returned %d\n", poll_return);

  if (poll_return < 0)
    {
      if (errno == EINTR)
	{
	  GSCheckTasks();
	  poll_return = 0;
	}
      else if (errno == 0)
	{
	  /* Some systems returns an errno == 0. Not sure why */
	  poll_return = 0;
	}
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
  fdEnd = pollfds_count;
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
	      watcher = (GSRunLoopWatcher*)NSMapGet(_efdMap, (void*)fd);
	      if (watcher != nil && watcher->_invalidated == NO)
		{
		  i = [contexts count];
		  while (i-- > 0)
		    {
		      GSRunLoopCtxt	*c = [contexts objectAtIndex: i];

		      if (c != self) [c endEvent: (void*)fd type: ET_EDESC];
		    }
		  /*
		   * The watcher is still valid - so call its
		   * receivers event handling method.
		   */
		  (*watcher->handleEvent)(watcher->receiver,
		    eventSel, watcher->data, watcher->type,
		    (void*)(gsaddr)fd, mode);
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
	      watcher = (GSRunLoopWatcher*)NSMapGet(_wfdMap, (void*)fd);
	      if (watcher != nil && watcher->_invalidated == NO)
		{
		  i = [contexts count];
		  while (i-- > 0)
		    {
		      GSRunLoopCtxt	*c = [contexts objectAtIndex: i];

		      if (c != self) [c endEvent: (void*)fd type: ET_WDESC];
		    }
		  /*
		   * The watcher is still valid - so call its
		   * receivers event handling method.
		   */
		  (*watcher->handleEvent)(watcher->receiver,
		    eventSel, watcher->data, watcher->type,
		    (void*)(gsaddr)fd, mode);
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
	      watcher = (GSRunLoopWatcher*)NSMapGet(_rfdMap, (void*)fd);
	      if (watcher != nil && watcher->_invalidated == NO)
		{
		  i = [contexts count];
		  while (i-- > 0)
		    {
		      GSRunLoopCtxt	*c = [contexts objectAtIndex: i];

		      if (c != self) [c endEvent: (void*)fd type: ET_RDESC];
		    }
		  /*
		   * The watcher is still valid - so call its
		   * receivers event handling method.
		   */
		  (*watcher->handleEvent)(watcher->receiver,
		    eventSel, watcher->data, watcher->type,
		    (void*)(gsaddr)fd, mode);
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
      else if (errno == 0)
	{
	  /* Some systems return an errno == 0. Not sure why */
	  select_return = 0;
	}
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

	  watcher = (GSRunLoopWatcher*)NSMapGet(_efdMap, (void*)fdIndex);
	  if (watcher != nil && watcher->_invalidated == NO)
	    {
	      i = [contexts count];
	      while (i-- > 0)
		{
		  GSRunLoopCtxt	*c = [contexts objectAtIndex: i];

		  if (c != self) [c endEvent: (void*)fdIndex type: ET_EDESC];
		}
	      /*
	       * The watcher is still valid - so call its receivers
	       * event handling method.
	       */
	      (*watcher->handleEvent)(watcher->receiver,
		eventSel, watcher->data, watcher->type,
		(void*)(gsaddr)fdIndex, mode);
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

	  watcher = (GSRunLoopWatcher*)NSMapGet(_wfdMap, (void*)fdIndex);
	  if (watcher != nil && watcher->_invalidated == NO)
	    {
	      i = [contexts count];
	      while (i-- > 0)
		{
		  GSRunLoopCtxt	*c = [contexts objectAtIndex: i];

		  if (c != self) [c endEvent: (void*)fdIndex type: ET_WDESC];
		}
	      /*
	       * The watcher is still valid - so call its receivers
	       * event handling method.
	       */
	      (*watcher->handleEvent)(watcher->receiver,
		eventSel, watcher->data, watcher->type,
		(void*)(gsaddr)fdIndex, mode);
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
	      i = [contexts count];
	      while (i-- > 0)
		{
		  GSRunLoopCtxt	*c = [contexts objectAtIndex: i];

		  if (c != self) [c endEvent: (void*)fdIndex type: ET_RDESC];
		}
	      /*
	       * The watcher is still valid - so call its receivers
	       * event handling method.
	       */
	      (*watcher->handleEvent)(watcher->receiver,
		eventSel, watcher->data, watcher->type,
		(void*)(gsaddr)fdIndex, mode);
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

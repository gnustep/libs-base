/* Implementation of object for waiting on several input sources
   Copyright (C) 1996, 1997 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

/* October 1996 - extensions to permit file descriptors to be watched
   for being readable or writable added by Richard Frith-Macdonald
   (richard@brainstorm.co.uk) */

/* This is the beginning of a RunLoop implementation.
   It is still in the early stages of development, and will most likely
   evolve quite a bit more before the interface settles.

   Does it strike anyone else that NSNotificationCenter,
   NSNotificationQueue, NSNotification, NSRunLoop, the "notifications"
   a run loop sends the objects on which it is listening, NSEvent, and
   the event queue maintained by NSApplication are all much more
   intertwined/similar than OpenStep gives them credit for?

   I wonder if these classes could be re-organized a little to make a
   more uniform, "grand-unified" mechanism for: events,
   event-listening, event-queuing, and event-distributing.  It could
   be quite pretty.

   (GNUstep would definitely provide classes that were compatible with
   all these OpenStep classes, but those classes could be wrappers
   around fundamentally cleaner GNU classes.  RMS has advised using an
   underlying organization/implementation different from NeXT's
   whenever that makes sense---it helps legally distinguish our work.)

   Thoughts and insights, anyone?

   */

/* Alternate names: InputDemuxer, InputListener, EventListener.
   Alternate names for Notification classes: Dispatcher, EventDistributor, */

#include <gnustep/base/preface.h>
#include <gnustep/base/Bag.h>
#include <gnustep/base/RunLoop.h>
#include <gnustep/base/Heap.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSNotificationQueue.h>

#ifdef _AIX
#include <sys/select.h>
#endif  /* AIX */

#ifndef __WIN32__
#include <sys/time.h>
#endif /* !__WIN32__ */

#include <limits.h>
#include <string.h>		/* for memset() */

/* On some systems FD_ZERO is a macro that uses bzero().
   Just define it to use memset(). */
#define bzero(PTR, LEN) memset (PTR, 0, LEN)


/* Local class to hold information about file descriptors to be watched
   and the objects to which messages are to be sent when the descriptors
   are readable or writable. */


@interface FdInfo: NSObject
{
    int		fd;
    id		receiver;
}
-(int)getFd;
-setFd:(int)desc;
-getReceiver;
-setReceiver:anObj;
-initWithFd:(int)desc andReceiver:anObj;
@end

@implementation FdInfo
-(int)getFd {
    return fd;
}
- setFd: (int)desc {
    fd = desc;
    return self;
}
-getReceiver {
    return receiver;
}
-setReceiver: anObj {
    if (receiver != nil) {
	[receiver release];
    }
    receiver = [anObj retain];
    return self;
}
-initWithFd:(int)desc andReceiver:anObj {	/* Designated initializer */
    [super init];
    [self setFd: desc];
    return [self setReceiver: anObj];
}
-init {
    return [self initWithFd:-1 andReceiver:nil];
}
-(void)dealloc {
    if (receiver != nil) {
        [receiver release];
    }
    [super dealloc];
}
@end


/* Adding and removing file descriptors. */

@implementation RunLoop(GNUstepExtensions)

- (void) addReadDescriptor: (int)fd
		    object: (id <FdListening>)listener
		   forMode: (NSString*)mode
{
  Bag		*fd_listeners;
  FdInfo	*info;

  if (mode == nil)
    mode = _current_mode;

  /* Remove any existing handler for the specified descriptor. */
  [self removeReadDescriptor: fd forMode: mode];

  /* Create new object to hold information. */
  info = [[FdInfo alloc] initWithFd: fd andReceiver: listener];

  /* Ensure we have a bag to put it in. */
  fd_listeners = NSMapGet (_mode_2_fd_listeners, mode);
  if (!fd_listeners)
    {
      fd_listeners = [Bag new];
      NSMapInsert (_mode_2_fd_listeners, mode, fd_listeners);
      [fd_listeners release];
    }

  /* Add our new handler information to the bag. */
  [fd_listeners addObject: info];
  [info release];
}

- (void) addWriteDescriptor: (int)fd
		    object: (id <FdSpeaking>)speaker
		   forMode: (NSString*)mode
{
  Bag		*fd_speakers;
  FdInfo	*info;

  if (mode == nil)
    mode = _current_mode;

  /* Remove any existing handler for the specified descriptor. */
  [self removeWriteDescriptor: fd forMode: mode];

  /* Create new object to hold information. */
  info = [[FdInfo alloc] initWithFd: fd andReceiver: speaker];

  /* Ensure we have a bag to put it in. */
  fd_speakers = NSMapGet (_mode_2_fd_speakers, mode);
  if (!fd_speakers)
    {
      fd_speakers = [Bag new];
      NSMapInsert (_mode_2_fd_speakers, mode, fd_speakers);
      [fd_speakers release];
    }

  /* Add our new handler information to the bag. */
  [fd_speakers addObject: info];
  [info release];
}

- (void) removeReadDescriptor: (int)fd 
		      forMode: (NSString*)mode
{
  Bag*	fd_listeners;

  if (mode == nil)
    mode = _current_mode;

  fd_listeners = NSMapGet (_mode_2_fd_listeners, mode);
  if (fd_listeners)
    {
      void*	es = [fd_listeners newEnumState];
      id	info;

      while ((info=[fd_listeners nextObjectWithEnumState: &es])!=NO_OBJECT)
        {
	  if ([info getFd] == fd)
            {
	      [fd_listeners removeObject: info];
	    }
	}
      [fd_listeners freeEnumState: &es];
    }
}

- (void) removeWriteDescriptor: (int)fd 
		      forMode: (NSString*)mode
{
  Bag*	fd_speakers;

  if (mode == nil)
    mode = _current_mode;

  fd_speakers = NSMapGet (_mode_2_fd_speakers, mode);
  if (fd_speakers)
    {
      void*	es = [fd_speakers newEnumState];
      id	info;

      while ((info=[fd_speakers nextObjectWithEnumState: &es])!=NO_OBJECT)
        {
	  if ([info getFd] == fd)
            {
	      [fd_speakers removeObject: info];
	    }
	}
      [fd_speakers freeEnumState: &es];
    }
}
@end


static int debug_run_loop = 0;

@implementation RunLoop

static RunLoop *current_run_loop;

+ (void) initialize
{
  if (self == [RunLoop class])
    current_run_loop = [self new];
}

/* This is the designated initializer. */
- init
{
  [super init];
  _current_mode = RunLoopDefaultMode;
  _mode_2_timers = NSCreateMapTable (NSNonRetainedObjectMapKeyCallBacks,
				     NSObjectMapValueCallBacks, 0);
  _mode_2_in_ports = NSCreateMapTable (NSNonRetainedObjectMapKeyCallBacks,
				       NSObjectMapValueCallBacks, 0);
  _mode_2_fd_listeners = NSCreateMapTable (NSNonRetainedObjectMapKeyCallBacks,
					   NSObjectMapValueCallBacks, 0);
  _mode_2_fd_speakers = NSCreateMapTable (NSNonRetainedObjectMapKeyCallBacks,
					 NSObjectMapValueCallBacks, 0);
  return self;
}

- (NSString*) currentMode
{
  return _current_mode;
}


/* Adding and removing port objects. */

- (void) addPort: port
         forMode: (NSString*)mode
{
  /* xxx Perhaps this should be a Bag instead; I think this currently works
     when a port is added more than once, but it doesn't work prettily. */
  Array *in_ports;

  in_ports = NSMapGet (_mode_2_in_ports, mode);
  if (!in_ports)
    {
      in_ports = [Array new];
      NSMapInsert (_mode_2_in_ports, mode, in_ports);
      [in_ports release];
    }
  [in_ports addObject: port];
}

- (void) removePort: port
            forMode: (NSString*)mode
{
  /* xxx Perhaps this should be a Bag instead. */
  Array *in_ports;

  in_ports = NSMapGet (_mode_2_in_ports, mode);
  if (in_ports)
    /* xxx Careful, this is only suppose to "undo" one -addPort:.
       If we change the -removeObject implementation later to remove
       all instances of port, we'll have to change this code here. */
    [in_ports removeObject: port];
}


/* Adding timers.  They are removed when they are invalid. */

- (void) addTimer: timer
	  forMode: (NSString*)mode
{
  Heap *timers;

  timers = NSMapGet (_mode_2_timers, mode);
  if (!timers)
    {
      timers = [Heap new];
      NSMapInsert (_mode_2_timers, mode, timers);
      [timers release];
    }
  /* xxx Should we make sure it isn't already there? */
  [timers addObject: timer];
}


/* Fire appropriate timers. */

- limitDateForMode: (NSString*)mode
{
  /* Linux doesn't always return double from methods, even though
     I'm using -lieee. */
  Heap *timers;
  NSTimer *min_timer = nil;
  id saved_mode;

  saved_mode = _current_mode;
  _current_mode = mode;

  timers = NSMapGet (_mode_2_timers, mode);
  if (!timers)
    {
      _current_mode = saved_mode;
      return nil;
    }
  
  /* Does this properly handle timers that have been sent -invalidate? */
  while ((min_timer = [timers minObject]) != nil)
    {
      if (![min_timer isValid])
	{
	  [timers removeFirstObject];
	  min_timer = nil;
	  continue;
	}

      if ([[min_timer fireDate] timeIntervalSinceNow] > 0)
	break;

      [min_timer retain];
      [timers removeFirstObject];
      /* Firing will also increment its fireDate, if it is repeating. */
      [min_timer fire];
      if ([min_timer isValid])
	{
	  [timers addObject: min_timer];
	}
      [min_timer release];
      min_timer = nil;
      [NSNotificationQueue runLoopASAP];	/* Post notifications. */
    }
  _current_mode = saved_mode;
  if (min_timer == nil)
    return nil;

  if (debug_run_loop)
    printf ("\tRunLoop limit date %f\n",
	    [[min_timer fireDate] timeIntervalSinceReferenceDate]);

  return [min_timer fireDate];
}



/*
  Because WIN32 is so vastly different from UNIX in the way it
  waits on file descriptors, sockets, and the event queue, I have
  separated them out into complete separate methods.  This will make
  it much easier to maintain and read versus if it was all jumbled
  together into a single method.

  Note that only one of the two methods will actually be compiled.
  */

#if defined(__WIN32__) || (_WIN32)

/* Private method
   Perform WIN32 style mechanism to wait on multiple inputs */
- (void) acceptWIN32InputForMode: (NSString*)mode 
		      beforeDate: limit_date
{
  DWORD wait_count = 0;
  HANDLE handle_list[MAXIMUM_WAIT_OBJECTS - 1];
  DWORD wait_timeout;
  struct timeval timeout;
  void *select_timeout;
  fd_set fds;			/* The file descriptors we will listen to. */
  fd_set read_fds;		/* Copy for listening to read-ready fds. */
  fd_set exception_fds;		/* Copy for listening to exception fds. */
  fd_set write_fds;		/* Copy for listening for write-ready fds. */
  int select_return;
  int fd_index;
  NSMapTable *fd_2_object;
  NSTimeInterval ti;
  id saved_mode;
  DWORD wait_return;
  id ports;
  int num_of_ports;
  int port_fd_count = 128; // xxx #define this constant
  int port_fd_array[port_fd_count];

  assert (mode);
  saved_mode = _current_mode;
  _current_mode = mode;

  /* Find out how much time we should wait, and set SELECT_TIMEOUT. */
  if (!limit_date)
    {
      /* Don't wait at all. */
      timeout.tv_sec = 0;
      timeout.tv_usec = 0;
      select_timeout = &timeout;
      wait_timeout = 0;
    }
  else if ((ti = [limit_date timeIntervalSinceNow]) < LONG_MAX
	    && ti > 0.0)
    {
      /* Wait until the LIMIT_DATE. */
      if (debug_run_loop)
	printf ("\tRunLoop accept input before %f (seconds from now %f)\n", 
		[limit_date timeIntervalSinceReferenceDate], ti);
      /* If LIMIT_DATE has already past, return immediately. */
      if (ti < 0)
	{
	  if (debug_run_loop)
	    printf ("\tRunLoop limit date past, returning\n");
          _current_mode = saved_mode;
	  return;
	}
      timeout.tv_sec = ti;
      timeout.tv_usec = (ti - timeout.tv_sec) * 1000000.0;
      select_timeout = &timeout;
      wait_timeout = ti * 1000;
    }
  else if (ti <= 0.0)
    {
      /* The LIMIT_DATE has already past; return immediately without
	 polling any inputs. */
      _current_mode = saved_mode;
      return;
    }
  else
    {
      /* Wait forever. */
      if (debug_run_loop)
	printf ("\tRunLoop accept input waiting forever\n");
      select_timeout = NULL;
      wait_timeout = INFINITE;
    }

#if 1
  /* Get ready to listen to file descriptors.
     Initialize the set of FDS we'll pass to select(), and create
     an empty map for keeping track of which object is associated
     with which file descriptor. */
  FD_ZERO (&fds);
  FD_ZERO (&write_fds);
  fd_2_object = NSCreateMapTable (NSIntMapKeyCallBacks,
				  NSObjectMapValueCallBacks, 0);

  /* If a port is invalid, remove it from this mode. */
  ports = NSMapGet (_mode_2_in_ports, mode);
  {
    id port;
    int i;
    for (i = [ports count]-1; i >= 0; i--)
      {
	port = [ports objectAtIndex: i];
	if (![port isValid])
	  [ports removeObjectAtIndex: i];
      }
  }
  num_of_ports = 0;

  /* Do the pre-listening set-up for the ports of this mode. */
  {
    if (ports)
      {
	id port;
	int i;
	int fd_count = port_fd_count;
	int fd_array[port_fd_count];

	/* Ask our ports for the list of file descriptors they
	   want us to listen to; add these to FD_LISTEN_SET. 
	   Save the list of ports for later use. */
	for (i = [ports count]-1; i >= 0; i--)
	  {
	    port = [ports objectAtIndex: i];
	    if ([port respondsTo: @selector(getFds:count:)])
	      [port getFds: fd_array count: &fd_count];
	    else
	      fd_count = 0;
	    if (debug_run_loop)
	      printf("\tRunLoop listening to %d sockets\n", fd_count);
	    num_of_ports += fd_count;
	    if (num_of_ports > port_fd_count)
	      {
		/* xxx Uh oh our array isn't big enough */
		perror ("RunLoop attempt to listen to too many ports\n");
		abort ();
	      }
	    while (fd_count--)
	      {
		int j = num_of_ports - fd_count - 1;
		port_fd_array[j] = fd_array[fd_count];
		FD_SET (port_fd_array[j], &fds);
		NSMapInsert (fd_2_object, 
			     (void*)port_fd_array[j], 
			     port);
	      }
	  }
      }
  }
  if (debug_run_loop)
    printf("\tRunLoop listening to %d total ports\n", num_of_ports);

  /* Wait for incoming data, listening to the file descriptors in _FDS. */
  read_fds = fds;
  exception_fds = fds;
  select_return = select (FD_SETSIZE, &read_fds, &write_fds, &exception_fds,
			  select_timeout);

  if (select_return < 0)
    {
      /* Some exceptional condition happened. */
      /* xxx We can do something with exception_fds, instead of
	 aborting here. */
      perror ("[TcpInPort receivePacketWithTimeout:] select()");
      abort ();
    }
  else if (select_return == 0)
    {
      NSFreeMapTable (fd_2_object);
      _current_mode = saved_mode;
      return;
    }
  
  /* Look at all the file descriptors select() says are ready for reading;
     notify the corresponding object for each of the ready fd's. */
  if (ports)
    {
      int i;

      for (i = num_of_ports - 1; i >= 0; i--)
	{
	  if (FD_ISSET (port_fd_array[i], &read_fds))
	    {
	      id fd_object = (id) NSMapGet (fd_2_object, 
					    (void*)port_fd_array[i]);
	      assert (fd_object);
	      [fd_object readyForReadingOnFileDescriptor: 
			   port_fd_array[i]];
	    }
	}
    }

  /* Clean up before returning. */
  NSFreeMapTable (fd_2_object);

#else

  /* Wait for incoming data */
  wait_return = MsgWaitForMultipleObjects(wait_count, handle_list, FALSE, 
					  wait_timeout, QS_ALLINPUT);

  if (debug_run_loop)
    printf ("\tRunLoop MsgWaitForMultipleObjects returned %ld\n", wait_return);

  if (wait_return == 0xFFFFFFFF)
    {
      /* Some exceptional condition happened. */
      NSLog(@"RunLoop error, MsgWaitForMultipleObjects returned %d\n",
	    GetLastError());
    }
  else if (wait_return == (WAIT_OBJECT_0 + wait_count))
    {
      /* Event in the event queue */
      if (_event_queue)
	[_event_queue readyForReadingOnEventQueue];
    }
  else
    {
      /* We handle the other wait objects here */
    }
#endif
  
  _current_mode = saved_mode;
}

#else

/* Private method
   Perform UNIX style mechanism to wait on multiple inputs */
- (void) acceptUNIXInputForMode: (NSString*)mode 
		     beforeDate: limit_date
{
  NSTimeInterval ti;
  struct timeval timeout;
  void *select_timeout;
  fd_set fds;			/* The file descriptors we will listen to. */
  fd_set read_fds;		/* Copy for listening to read-ready fds. */
  fd_set exception_fds;		/* Copy for listening to exception fds. */
  fd_set write_fds;		/* Copy for listening for write-ready fds. */
  int select_return;
  int fd_index;
  NSMapTable *rfd_2_object;
  NSMapTable *wfd_2_object;
  id saved_mode;
  int num_inputs = 0;

  assert (mode);
  saved_mode = _current_mode;
  _current_mode = mode;

  /* Find out how much time we should wait, and set SELECT_TIMEOUT. */
  if (!limit_date)
    {
      /* Don't wait at all. */
      timeout.tv_sec = 0;
      timeout.tv_usec = 0;
      select_timeout = &timeout;
    }
  else if ((ti = [limit_date timeIntervalSinceNow]) < LONG_MAX
	    && ti > 0.0)
    {
      /* Wait until the LIMIT_DATE. */
      if (debug_run_loop)
	printf ("\tRunLoop accept input before %f (seconds from now %f)\n", 
		[limit_date timeIntervalSinceReferenceDate], ti);
      /* If LIMIT_DATE has already past, return immediately. */
      if (ti < 0)
	{
	  if (debug_run_loop)
	    printf ("\tRunLoop limit date past, returning\n");
          _current_mode = saved_mode;
	  return;
	}
      timeout.tv_sec = ti;
      timeout.tv_usec = (ti - timeout.tv_sec) * 1000000.0;
      select_timeout = &timeout;
    }
  else if (ti <= 0.0)
    {
      /* The LIMIT_DATE has already past; return immediately without
	 polling any inputs. */
      _current_mode = saved_mode;
      return;
    }
  else
    {
      /* Wait forever. */
      if (debug_run_loop)
	printf ("\tRunLoop accept input waiting forever\n");
      select_timeout = NULL;
    }

  /* Get ready to listen to file descriptors.
     Initialize the set of FDS we'll pass to select(), and create
     an empty map for keeping track of which object is associated
     with which file descriptor. */
  FD_ZERO (&fds);
  FD_ZERO (&write_fds);
  rfd_2_object = NSCreateMapTable (NSIntMapKeyCallBacks,
				  NSObjectMapValueCallBacks, 0);
  wfd_2_object = NSCreateMapTable (NSIntMapKeyCallBacks,
				  NSObjectMapValueCallBacks, 0);


  /* Do the pre-listening set-up for the file descriptors of this mode. */
  {
      Bag*	fdInfo;

      fdInfo = NSMapGet (_mode_2_fd_speakers, mode);
      if (fdInfo) {
	  void*	es = [fdInfo newEnumState];
	  id	info;

	  while ((info=[fdInfo nextObjectWithEnumState: &es])!=NO_OBJECT) {
	      int	fd = [info getFd];

	      FD_SET (fd, &write_fds);
	      NSMapInsert (wfd_2_object, (void*)fd, [info getReceiver]);
	      num_inputs++;
	  }
	  [fdInfo freeEnumState: &es];
      }
      fdInfo = NSMapGet (_mode_2_fd_listeners, mode);
      if (fdInfo) {
	  void*	es = [fdInfo newEnumState];
	  id	info;

	  while ((info=[fdInfo nextObjectWithEnumState: &es])!=NO_OBJECT) {
	      int	fd = [info getFd];

	      FD_SET (fd, &fds);
	      NSMapInsert (rfd_2_object, (void*)fd, [info getReceiver]);
	      num_inputs++;
	  }
	  [fdInfo freeEnumState: &es];
      }
  }

  /* Do the pre-listening set-up for the ports of this mode. */
  {
    id ports = NSMapGet (_mode_2_in_ports, mode);
    if (ports)
      {
	id port;
	int i;

	/* If a port is invalid, remove it from this mode. */
	for (i = [ports count]-1; i >= 0; i--)
	  {
	    port = [ports objectAtIndex: i];
	    if (![port isValid])
	      [ports removeObjectAtIndex: i];
	  }

	/* Ask our ports for the list of file descriptors they
	   want us to listen to; add these to FD_LISTEN_SET. */
	for (i = [ports count]-1; i >= 0; i--)
	  {
	    int port_fd_count = 128; // xxx #define this constant
	    int port_fd_array[port_fd_count];
	    port = [ports objectAtIndex: i];
	    if ([port respondsTo: @selector(getFds:count:)])
	      [port getFds: port_fd_array count: &port_fd_count];
	    if (debug_run_loop)
	      printf("\tRunLoop listening to %d sockets\n", port_fd_count);
	    while (port_fd_count--)
	      {
		FD_SET (port_fd_array[port_fd_count], &fds);
		NSMapInsert (rfd_2_object, 
			     (void*)port_fd_array[port_fd_count], port);
		num_inputs++;
	      }
	  }
      }
  }

  /* Wait for incoming data, listening to the file descriptors in _FDS. */
  read_fds = fds;
  exception_fds = fds;

  /* Detect if the RunLoop is idle, and if necessary - dispatch the
     notifications from NSNotificationQueue's idle queue? */
  if (num_inputs == 0 && [NSNotificationQueue runLoopMore])
    {
      timeout.tv_sec = 0;
      timeout.tv_usec = 0;
      select_timeout = &timeout;
      select_return = select (FD_SETSIZE, &read_fds, &write_fds, &exception_fds,
			  select_timeout);
    }
  else
    select_return = select (FD_SETSIZE, &read_fds, &write_fds, &exception_fds,
			  select_timeout);

  if (debug_run_loop)
    printf ("\tRunLoop select returned %d\n", select_return);

  if (select_return < 0)
    {
      /* Some exceptional condition happened. */
      /* xxx We can do something with exception_fds, instead of
	 aborting here. */
      perror ("[TcpInPort receivePacketWithTimeout:] select()");
      abort ();
    }
  else if (select_return == 0)
    {
      NSFreeMapTable (rfd_2_object);
      NSFreeMapTable (wfd_2_object);
      [NSNotificationQueue runLoopIdle];
      [NSNotificationQueue runLoopASAP];
      _current_mode = saved_mode;
      return;
    }
  
  /* Look at all the file descriptors select() says are ready for reading;
     notify the corresponding object for each of the ready fd's. */
  for (fd_index = 0; fd_index < FD_SETSIZE; fd_index++)
    {
      if (FD_ISSET (fd_index, &write_fds))
        {
	  id fd_object = (id) NSMapGet (wfd_2_object, (void*)fd_index);
	  assert (fd_object);
	  [fd_object readyForWritingOnFileDescriptor: fd_index];
          [NSNotificationQueue runLoopASAP];
        }
      if (FD_ISSET (fd_index, &read_fds))
        {
	  id fd_object = (id) NSMapGet (rfd_2_object, (void*)fd_index);
	  assert (fd_object);
	  [fd_object readyForReadingOnFileDescriptor: fd_index];
          [NSNotificationQueue runLoopASAP];
        }
    }
  /* Clean up before returning. */
  NSFreeMapTable (rfd_2_object);
  NSFreeMapTable (wfd_2_object);

  _current_mode = saved_mode;
}

#endif /* WIN32 */

/* Listen to input sources.
   If LIMIT_DATE is nil, then don't wait; i.e. call select() with 0 timeout */

- (void) acceptInputForMode: (NSString*)mode 
		 beforeDate: limit_date
{
#if defined(__WIN32__) || defined(_WIN32)
  [self acceptWIN32InputForMode: mode beforeDate: limit_date];
#else
  [self acceptUNIXInputForMode: mode beforeDate: limit_date];
#endif /* WIN32 */
}



/* Running the run loop once through for timers and input listening. */

- (BOOL) runOnceBeforeDate: date forMode: (NSString*)mode
{
  id d;

  /* If DATE is already later than now, just return. */
  if ([date timeIntervalSinceNow] < 0)
    {
      if (debug_run_loop)
	printf ("\tRunLoop run mode before date already past\n");
      return NO;
    }

  /* Find out how long we can wait; and fire timers that are ready. */
  d = [self limitDateForMode: mode];
  if (!d)
    d = date;

  /* Wait, listening to our input sources. */
  [self acceptInputForMode: mode
	beforeDate: d];

  return YES;
}

- (BOOL) runOnceBeforeDate: date
{
  return [self runOnceBeforeDate: date forMode: _current_mode];
}


/* Running the run loop multiple times through. */

- (void) runUntilDate: date forMode: (NSString*)mode
{
  volatile double ti;

  ti = [date timeIntervalSinceNow];
  /* Positive values are in the future. */
  while (ti > 0)
    {
      id arp = [NSAutoreleasePool new];
      if (debug_run_loop)
	printf ("\tRunLoop run until date %f seconds from now\n", ti);
      [self runOnceBeforeDate: date forMode: mode];
      [arp release];
      ti = [date timeIntervalSinceNow];
    }
}

- (void) runUntilDate: date
{
  [self runUntilDate: date forMode: _current_mode];
}

- (void) run
{
  [self runUntilDate: [NSDate distantFuture]];
}


/* Class methods that send messages to the current instance. */

+ (void) run
{
  assert (current_run_loop);
  [current_run_loop run];
}

+ (void) runUntilDate: date
{
  assert (current_run_loop);
  [current_run_loop runUntilDate: date];
}

+ (void) runUntilDate: date forMode: (NSString*)mode
{
  assert (current_run_loop);
  [current_run_loop runUntilDate: date forMode: mode];
}

+ (BOOL) runOnceBeforeDate: date 
{
  return [current_run_loop runOnceBeforeDate: date];
}

+ (BOOL) runOnceBeforeDate: date forMode: (NSString*)mode
{
  return [current_run_loop runOnceBeforeDate: date forMode: mode];
}

+ currentInstance
{
  assert (current_run_loop);
  return current_run_loop;
}

+ (NSString*) currentMode
{
  return [current_run_loop currentMode];
}

@end


/* NSObject method additions. */

@implementation NSObject (PerformingAfterDelay)

- (void) performSelector: (SEL)sel afterDelay: (NSTimeInterval)delay
{
  [self notImplemented: _cmd];
}

@end



#if 0
- getNotificationWithName: (NSString*)name
		   object: object
		   inMode: (NSString*)mode
               beforeDate: date
{
  /* See if any timers should fire, and fire them. */

  /* Figure out how long we can listen to file descriptors before, either,
     we need to fire another timer, or we need to return before DATE. */

  /* Wait, listening to the file descriptors. */

  /* Process active file descriptors. */

  /* Is it time to return?  If not, go back and check timers, 
     otherwise return. */
}

/* Some alternate names */
- waitForNotificationWithName: (NSString*)name
		       object: object
		       inMode: (NSString*)mode
                    untilDate: date
{
}

@end


/* The old alternate names */
- (void) makeNotificationsForFileDescriptor: (int)fd
				    forMode: (NSString*)mode
				       name: (NSString*)name
                                     object: object
                                  postingTo: (id <NotificationPosting>)poster
			       postingStyle: style
- (void) addFileDescriptor: (int)fd
		   forMode: (NSString*)mode
	   postingWithName: (NSString*)name
                    object: object;
- (void) addFileDescriptor: (int)fd 
	      withAttender: (id <FileDescriptorAttending>)object
- (void) addObserver: observer
	    selector: (SEL)
	      ofName: fileDescriptorString
	      withAttender: (id <FileDescriptorAttending>)object

#endif


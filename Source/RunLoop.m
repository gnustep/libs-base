/* Implementation of object for waiting on several input sources
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996

   This file is part of the GNU Objective C Class Library.

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

/* This is the beginning of a RunLoop implementation.
   It is still in the early stages of development, and will most likely
   evolve quite a bit more before the interface settles.

   Distinguishing between different MODES is not currently implemented.
   Handling NSTimers is implemented, but currently disabled.

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

#include <objects/stdobjects.h>
#include <objects/RunLoop.h>
#include <objects/Heap.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSTimer.h>
#include <sys/time.h>
#include <limits.h>
#include <string.h>		/* for memset() */

/* On some systems FD_ZERO is a macro that uses bzero().
   Just define it to use memset(). */
#define bzero(PTR, LEN) memset (PTR, 0, LEN)

static int debug_run_loop = 1;

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
  return self;
}

- (id <String>) currentMode
{
  return _current_mode;
}


/* Adding and removing file descriptors. */

- (void) addFileDescriptor: (int)fd
		    object: listener
		   forMode: (id <String>)mode
{
  /* xxx Perhaps this should be a Bag instead. */
  Array *fd_listeners;

  /* xxx We need to keep track of the FD too!
     Perhaps I'll make a FileDescriptor class to hold all this;
     it will be more analogous the Port object. */
  [self notImplemented: _cmd];

  fd_listeners = NSMapGet (_mode_2_fd_listeners, mode);
  if (!fd_listeners)
    {
      fd_listeners = [Array new];
      NSMapInsert (_mode_2_fd_listeners, mode, fd_listeners);
      [fd_listeners release];
    }
  [fd_listeners addObject: listener];
}

- (void) removeFileDescriptor: (int)fd 
		      forMode: (id <String>)mode
{
#if 1
  [self notImplemented: _cmd];
#else
  Array *fd_listeners;

  fd_listeners = NSMapGet (_mode_2_fd_listeners, mode);
  if (!fd_listeners)
    /* xxx Careful, this is only suppose to "undo" one -addPort:.
       If we change the -removeObject implementation later to remove
       all instances of port, we'll have to change this code here. */
    [fd_listeners removeObject: port];
#endif
}


/* Adding and removing port objects. */

- (void) addPort: port
         forMode: (id <String>)mode
{
  /* xxx Perhaps this should be a Bag instead. */
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
            forMode: (id <String>)mode
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
	  forMode: (id <String>)mode
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

- limitDateForMode: (id <String>)mode
{
  /* Linux doesn't always return double from methods, even though
     I'm using -lieee. */
#if 1
  return nil;
#else
  Heap *timers;
  NSTimer *min_timer = nil;
  id saved_mode;

  saved_mode = _current_mode;
  _current_mode = mode;

  timers = NSMapGet (_mode_2_timers, mode);
  if (!timers)
    return nil;

  /* Does this properly handle timers that have been sent -invalidate? */
  while ((min_timer = [timers minObject])
	 && ([[min_timer fireDate] timeIntervalSinceNow] > 0))
    {
      [timers removeFirstObject];
      /* Firing will also increment its fireDate, if it is repeating. */
      if ([min_timer isValid])
	{
	  [min_timer fire];
	  if ([[min_timer fireDate] timeIntervalSinceNow] < 0)
	    [timers addObject: min_timer];
	}
    }
  if (debug_run_loop)
    printf ("\tlimit date %f\n", 
	    [[min_timer fireDate] timeIntervalSinceReferenceDate]);

  _current_mode = saved_mode;
  return [min_timer fireDate];
#endif
}


/* Listen to input sources */

- (void) acceptInputForMode: (id <String>)mode 
		 beforeDate: limit_date
{
  NSTimeInterval ti;
  struct timeval timeout;
  void *select_timeout;
  fd_set fds;			/* The file descriptors we will listen to. */
  fd_set read_fds;		/* Copy for listening to read-ready fds. */
  fd_set exception_fds;		/* Copy for listening to exception fds. */
  int select_return;
  int fd_index;
  NSMapTable *fd_2_object;
  id saved_mode;

  saved_mode = _current_mode;
  _current_mode = mode;

  /* xxx No, perhaps this isn't the right thing to do. */
#if 0
  /* If there are no input sources to listen to, just return. */
  if (NSCountMapTable (_fd_2_object) == 0)
    return;
#endif

  /* Find out how much time we should wait, and set SELECT_TIMEOUT. */
  if (limit_date 
      && ((ti = [limit_date timeIntervalSinceNow]) < LONG_MAX))
    {
      if (debug_run_loop)
	printf ("\taccept input before %f (seconds from now %f)\n", 
		[limit_date timeIntervalSinceReferenceDate], ti);
      /* If LIMIT_DATE has already past, return immediately. */
      if (ti < 0)
	{
	  if (debug_run_loop)
	    printf ("\tlimit date past, returning\n");
	  return;
	}

      timeout.tv_sec = ti;
      timeout.tv_usec = ti * 1000000.0;
      select_timeout = &timeout;
    }
  else
    {
      if (debug_run_loop)
	printf ("\taccept input waiting forever\n");
      select_timeout = NULL;
    }

  /* Get ready to listen to file descriptors.
     Initialize the set of FDS we'll pass to select(), and create
     an empty map for keeping track of which object is associated
     with which file descriptor. */
  FD_ZERO (&fds);
  fd_2_object = NSCreateMapTable (NSIntMapKeyCallBacks,
				  NSObjectMapValueCallBacks, 0);


  /* Do the pre-listening set-up for the file descriptors of this mode. */
  {
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
	    int port_fd_count = 128;
	    int port_fd_array[port_fd_count];
	    port = [ports objectAtIndex: i];
	    if ([port respondsTo: @selector(getFds:count:)])
	      [port getFds: port_fd_array count: &port_fd_count];
	    while (port_fd_count--)
	      {
		FD_SET (port_fd_array[port_fd_count], &fds);
		NSMapInsert (fd_2_object, 
			     (void*)port_fd_array[port_fd_count], port);
	      }
	  }
      }
  }

  /* Wait for incoming data, listening to the file descriptors in _FDS. */
  read_fds = fds;
  exception_fds = fds;
  select_return = select (FD_SETSIZE, &read_fds, NULL, &exception_fds,
			  select_timeout);

  if (debug_run_loop)
    printf ("\tselect returned %d\n", select_return);

  if (select_return < 0)
    {
      /* Some exceptional condition happened. */
      /* xxx We can do something with exception_fds, instead of
	 aborting here. */
      perror ("[TcpInPort receivePacketWithTimeout:] select()");
      abort ();
    }
  else if (select_return == 0)
    return;
  
  /* Look at all the file descriptors select() says are ready for reading;
     notify the corresponding object for each of the ready fd's. */
  for (fd_index = 0; fd_index < FD_SETSIZE; fd_index++)
    if (FD_ISSET (fd_index, &read_fds))
      {
	id fd_object = (id) NSMapGet (fd_2_object, (void*)fd_index);
	assert (fd_object);
	[fd_object readyForReadingOnFileDescriptor: fd_index];
      }

  /* Clean up before returning. */
  NSFreeMapTable (fd_2_object);
  _current_mode = saved_mode;
}


/* Running the run loop once through for timers and input listening. */

- (BOOL) runOnceBeforeDate: date forMode: (id <String>)mode
{
  id d;

  /* If DATE is already later than now, just return. */
  if ([date timeIntervalSinceNow] < 0)
    {
      if (debug_run_loop)
	printf ("\trun mode before date already past\n");
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

- (void) runUntilDate: date forMode: (id <String>)mode
{
  volatile double ti;

  ti = [date timeIntervalSinceNow];
  /* Positive values are in the future. */
  while (ti > 0)
    {
      id arp = [NSAutoreleasePool new];
      if (debug_run_loop)
	printf ("\trun until date %f seconds from now\n", ti);
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

+ (void) runUntilDate: date forMode: (id <String>)mode
{
  assert (current_run_loop);
  [current_run_loop runUntilDate: date forMode: mode];
}

+ (BOOL) runOnceBeforeDate: date 
{
  return [current_run_loop runOnceBeforeDate: date];
}

+ (BOOL) runOnceBeforeDate: date forMode: (id <String>)mode
{
  return [current_run_loop runOnceBeforeDate: date forMode: mode];
}

+ currentInstance
{
  assert (current_run_loop);
  return current_run_loop;
}

+ (id <String>) currentMode
{
  return [current_run_loop currentMode];
}

@end


/* RunLoop mode strings. */

id RunLoopDefaultMode = @"RunLoopDefaultMode";


/* NSObject method additions. */

@implementation NSObject (PerformingAfterDelay)

- (void) performSelector: (SEL)sel afterDelay: (NSTimeInterval)delay
{
  [self notImplemented: _cmd];
}

@end



#if 0
- getNotificationWithName: (id <String>)name
		   object: object
		   inMode: (id <String>)mode
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
- waitForNotificationWithName: (id <String>)name
		       object: object
		       inMode: (id <String>)mode
                    untilDate: date
{
}

@end


/* The old alternate names */
- (void) makeNotificationsForFileDescriptor: (int)fd
				    forMode: (id <String>)mode
				       name: (id <String>)name
                                     object: object
                                  postingTo: (id <NotificationPosting>)poster
			       postingStyle: style
- (void) addFileDescriptor: (int)fd
		   forMode: (id <String>)mode
	   postingWithName: (id <String>)name
                    object: object;
- (void) addFileDescriptor: (int)fd 
	      withAttender: (id <FileDescriptorAttending>)object
- (void) addObserver: observer
	    selector: (SEL)
	      ofName: fileDescriptorString
	      withAttender: (id <FileDescriptorAttending>)object

#endif

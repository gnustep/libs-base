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

#include <objects/stdobjects.h>
#include <objects/RunLoop.h>
#include <objects/Heap.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSTimer.h>
#include <sys/time.h>
#include <nan.h>
#include <limits.h>

/* Alternate names: InputDemuxer, InputListener
   Alternate names for Notification classes: Dispatcher, EventDistributor, */

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
  FD_ZERO (&_fds);
  _fd_2_object = NSCreateMapTable (NSIntMapKeyCallBacks,
				   NSObjectMapValueCallBacks, 0);
  _fd_objects = [Bag new];
  _timers = [Heap new];
  _dispatcher = [NotificationDispatcher defaultInstance];
  return self;
}

- notificationDispatcher
{
  return _dispatcher;
}

- (void) setNotificationDispatcher: d
{
  _dispatcher = d;
}


/* xxx This is similar to [NotificationDispatcher addObserver...]
   Perhaps NotificationDispatcher and InputDemuxer will be merged. */

- (void) addFileDescriptor: (int)fd
		invocation: invocation
		   forMode: (id <String>)mode
{
  /* xxx But actually we should let it be added multiple times,
     and keep count. (?) */
  if (debug_run_loop)
    printf ("\tRunLoop adding fd %d\n", fd);
  assert (!NSMapGet (_fd_2_object, (void*)fd));
  NSMapInsert (_fd_2_object, (void*)fd, invocation);
  FD_SET (fd, &_fds);
}

- (void) removeFileDescriptor: (int)fd 
		      forMode: (id <String>)mode
{
  if (debug_run_loop)
    printf ("\tRunLoop removing fd %d\n", fd);
  assert (NSMapGet (_fd_2_object, (void*)fd));
  NSMapRemove (_fd_2_object, (void*)fd);
  FD_CLR (fd, &_fds);
}

- (void) addTimer: timer
	  forMode: (id <String>)mode
{
  assert (_timers);
  [_timers addObjectIfAbsent: timer];
}


/* Running the loop. */

- limitDateForMode: (id <String>)mode
{
#if 1
  return nil;
#else
  NSTimer *min_timer = nil;

  /* Does this properly handle timers that have been sent -invalidate? */
  while ((min_timer = [_timers minObject])
	 && ([[min_timer fireDate] timeIntervalSinceNow] > 0))
    {
      [_timers removeFirstObject];
      /* Firing will also increment its fireDate, if it is repeating. */
      if ([min_timer isValid])
	{
	  [min_timer fire];
	  if ([[min_timer fireDate] timeIntervalSinceNow] < 0)
	    [_timers addObject: min_timer];
	}
    }
  if (debug_run_loop)
    printf ("\tlimit date %f\n", 
	    [[min_timer fireDate] timeIntervalSinceReferenceDate]);
  return [min_timer fireDate];
#endif
}

- (void) acceptInputForMode: (id <String>)mode 
		 beforeDate: limit_date
{
  NSTimeInterval ti;
  struct timeval timeout;
  void *select_timeout;
  fd_set fds_copy;
  int select_return;
  int fd_index;

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

  fds_copy = _fds;

  /* Wait for incoming data, listening to the file descriptors in FDS. */
  select_return = select (FD_SETSIZE, &fds_copy, NULL, NULL, select_timeout);

  if (debug_run_loop)
    printf ("\tselect returned %d\n", select_return);

  if (select_return < 0)
    {
      perror ("[TcpInPort receivePacketWithTimeout:] select()");
      abort ();
    }
  else if (select_return == 0)
    return;

  /* Look at all the file descriptors select() says are ready for reading;
     invoke the corresponding invocation for each of the ready ones. */
  for (fd_index = 0; fd_index < FD_SETSIZE; fd_index++)
    if (FD_ISSET (fd_index, &fds_copy))
      {
	id fd_invocation = (id) NSMapGet (_fd_2_object, (void*)fd_index);
	assert (fd_invocation);
	[fd_invocation
	  invokeWithObject: [NSNumber numberWithInt: fd_index]];
	/* xxx We can get rid of this NSNumber autorelease later. */
      }
}

- (BOOL) runMode: (id <String>)mode 
      beforeDate: date
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
  d = [self limitDateForMode: nil];
  if (!d)
    d = date;

  /* Wait, listening to our input sources. */
  [self acceptInputForMode: mode
	beforeDate: d];
  return YES;
}

- (BOOL) runOnceBeforeDate: date
		   forMode: (id <String>)mode
{
  return [self runMode: mode beforeDate: date];
}

- (void) runUntilDate: date
{
  volatile double ti;

  ti = [date timeIntervalSinceNow];
  assert (ti != NAN);
  /* Positive values are in the future. */
  while (ti > 0)
    {
      id arp = [NSAutoreleasePool new];
      if (debug_run_loop)
	printf ("\trun until date %f seconds from now\n", ti);
      [self runMode: nil beforeDate: date];
      [arp release];
      ti = [date timeIntervalSinceNow];
    }
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

+ currentInstance
{
  assert (current_run_loop);
  return current_run_loop;
}

@end



@implementation NSObject (PerformingAfterDelay)

- (void) performSelector: (SEL)sel afterDelay: (NSTimeInterval)delay
{
  
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

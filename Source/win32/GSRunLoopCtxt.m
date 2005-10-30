/**
 * The GSRunLoopCtxt stores context information to handle polling for
 * events.  This information is associated with a particular runloop
 * mode, and persists throughout the life of the runloop instance.
 *
 *	NB.  This class is private to NSRunLoop and must not be subclassed.
 */

#include "config.h"

#include "GNUstepBase/preface.h"
#include "../GSRunLoopCtxt.h"
#include "../GSRunLoopWatcher.h"
#include <Foundation/NSDebug.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSPort.h>

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
  if (handleMap != 0)
    {
      NSFreeMapTable(handleMap);
    }
  if (winMsgMap != 0)
    {
      NSFreeMapTable(winMsgMap);
    }
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
	  case ET_HANDLE:
	    break;
	  case ET_WINMSG:
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

      handleMap = NSCreateMapTable(NSIntMapKeyCallBacks,
              WatcherMapValueCallBacks, 0);
      winMsgMap = NSCreateMapTable(NSIntMapKeyCallBacks,
              WatcherMapValueCallBacks, 0);

      msgTarget = nil;
    }
  return self;
}

- (BOOL) pollUntil: (int)milliseconds within: (NSArray*)contexts
{
  NSMapEnumerator	hEnum;
  GSRunLoopWatcher	*watcher;
  HANDLE		handleArray[MAXIMUM_WAIT_OBJECTS-1];
  int			num_handles;
  int			num_winMsgs;
  unsigned		i;
  void			*handle;
  int			wait_timeout;
  DWORD			wait_return;
  BOOL			do_wait;

  // Set timeout how much time should wait
  if (milliseconds >= 0)
    {
      wait_timeout = milliseconds;
    }
  else
    {
      wait_timeout = INFINITE;
    }

  NSResetMapTable(handleMap);
  NSResetMapTable(winMsgMap);

  i = GSIArrayCount(watchers);
  num_handles = 0;
  num_winMsgs = 0;
  while (i-- > 0)
    {
      GSRunLoopWatcher	*info;
      HANDLE		handle;
      
      info = GSIArrayItemAtIndex(watchers, i).obj;
      if (info->_invalidated == YES)
	{
	  GSIArrayRemoveItemAtIndex(watchers, i);
	  continue;
	}
      switch (info->type)
	{
	  case ET_HANDLE:
    	    handle = (HANDLE)(int)info->data;
            NSMapInsert(handleMap, (void*)handle, info);
	    num_handles++;
	    break;
	  case ET_RPORT:
	    {
              id port = info->receiver;
              int port_handle_count = 128; // #define this constant
              int port_handle_array[port_handle_count];
              if ([port respondsToSelector: @selector(getFds:count:)])
                {
		  [port getFds: port_handle_array count: &port_handle_count];
		}
	      else
	        {
	          NSLog(@"pollUntil - Impossible get win32 Handles");
		  abort();
                }
              NSDebugMLLog(@"NSRunLoop", @"listening to %d port handles",
	        port_handle_count);
              while (port_handle_count--)
		{
                  NSMapInsert(handleMap, 
		    (void*)port_handle_array[port_handle_count], info);
                  num_handles++;
		}
            }
	    break;
	  case ET_WINMSG:
    	    handle = (HANDLE)(int)info->data;
            NSMapInsert(winMsgMap, (void*)handle, info);
	    num_winMsgs++;
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
      wait_timeout = 0;
    }

  i = 0;
  hEnum = NSEnumerateMapTable(handleMap);
  while (NSNextMapEnumeratorPair(&hEnum, &handle, (void**)&watcher))
    {
      if (i < MAXIMUM_WAIT_OBJECTS-1)
	{
	  handleArray[i++] = (HANDLE)handle;
	}
      else
	{
	  NSLog(@"Too many handles to wait for ... only using %d of %d",
	    i, num_handles);
	}
    }
  NSEndMapTableEnumeration(&hEnum);
  num_handles = i;

  do_wait = YES;
  do
    {
      wait_return = MsgWaitForMultipleObjects(num_handles, handleArray, 
	NO, wait_timeout, QS_ALLINPUT);
      NSDebugMLLog(@"NSRunLoop", @"wait returned %d", wait_return);

      // if there are windows message
      if (wait_return == WAIT_OBJECT_0 + num_handles)
        {
	  MSG	msg;
	  INT	bRet;

	  if (msgTarget == nil)
	    {
	      bRet = PeekMessage(&msg, 0, 0, 0, PM_REMOVE);
	      if (bRet != 0)
		{
		  if (num_winMsgs > 0)
		    {
		      HANDLE	handle;

		      handle = msg.hwnd;
		      watcher = (GSRunLoopWatcher*)NSMapGet(winMsgMap,
			(void*)handle);
		      if (watcher == nil || watcher->_invalidated == YES)
			{
			  handle = 0;	// Generic
			  watcher = (GSRunLoopWatcher*)NSMapGet(winMsgMap,
			    (void*)handle);
			}
		      if (watcher != nil && watcher->_invalidated == NO)
			{
			  i = [contexts count];
			  while (i-- > 0)
			    {
			      GSRunLoopCtxt *c = [contexts objectAtIndex: i];

			      if (c != self)
				{ 
				  [c endEvent: (void*)handle type: ET_WINMSG];
				}
			    }
			  completed = YES;
			  /*
			   * The watcher is still valid - so call the
			   * receiver's event handling method.
			   */
			  (*watcher->handleEvent)(watcher->receiver,
			    eventSel, watcher->data, watcher->type,
			    (void*)(gsaddr)&msg, mode);
			  return NO;
			}
		    }
		  DispatchMessage(&msg);
		}
	    }
	  else
	    {
	      if (num_winMsgs > 0)
		{
		  GSRunLoopWatcher	*generic = nil;
		  unsigned		num = num_winMsgs;

		  hEnum = NSEnumerateMapTable(winMsgMap);
		  while (NSNextMapEnumeratorPair(&hEnum, &handle,
		    (void**)&watcher))
		    {
		      if (watcher->_invalidated == NO)
			{
			  if (handle == 0 && num > 1)
			    {
			      // Let window specific watchers have first attempt.
			      generic = watcher;
			      continue;
			    }
			  bRet = PeekMessage(&msg, handle, 0, 0, PM_REMOVE);
			  if (bRet != 0)
			    {
			      i = [contexts count];
			      while (i-- > 0)
				{
				  GSRunLoopCtxt *c = [contexts objectAtIndex: i];

				  if (c != self)
				    { 
				      [c endEvent: (void*)handle
					     type: ET_WINMSG];
				    }
				}
			      NSEndMapTableEnumeration(&hEnum);
			      completed = YES;
			      /*
			       * The watcher is still valid - so call the
			       * receiver's event handling method.
			       */
			      (*watcher->handleEvent)(watcher->receiver,
				  eventSel, watcher->data, watcher->type,
				  (void*)(gsaddr)&msg, mode);
			      return NO;
			    }
			}
		      num--;
		    }
		  NSEndMapTableEnumeration(&hEnum);
		  if (generic != nil && generic->_invalidated == NO)
		    {
		      bRet = PeekMessage(&msg, 0, 0, 0, PM_REMOVE);
		      if (bRet != 0)
			{
			  i = [contexts count];
			  while (i-- > 0)
			    {
			      GSRunLoopCtxt *c = [contexts objectAtIndex: i];

			      if (c != self)
				{ 
				  [c endEvent: (void*)0 type: ET_WINMSG];
				}
			    }
			  NSEndMapTableEnumeration(&hEnum);
			  completed = YES;
			  (*generic->handleEvent)(watcher->receiver,
			      eventSel, watcher->data, watcher->type,
			      (void*)(gsaddr)&msg, mode);
			  return NO;
			}
		    }
		}
	      completed = YES;
	      [msgTarget performSelector: msgSelector withObject: nil];
	      return NO;
	    }
          --wait_timeout;
        }
      else
        {
          do_wait = NO;
        }
    }
  while (do_wait && (wait_timeout >= 0));

  // check wait errors
  if (wait_return == WAIT_FAILED)
    {
      NSLog(@"WaitForMultipleObjects() error in -acceptInputForMode:beforeDate: '%d'",
          GetLastError());
      abort ();        
    }

  // if there arent events
  if (wait_return == WAIT_TIMEOUT)
    {
      completed = YES;
      return NO;        
    }
  
  /*
   * Look the event that WaitForMultipleObjects() says is ready;
   * get the corresponding fd for that handle event and notify
   * the corresponding object for the ready fd.
   */
  i = wait_return - WAIT_OBJECT_0;

  NSDebugMLLog(@"NSRunLoop", @"Event listen %d", i);
  
  handle = handleArray[i];

  watcher = (GSRunLoopWatcher*)NSMapGet(handleMap, (void*)handle);
  if (watcher != nil && watcher->_invalidated == NO)
    {
      i = [contexts count];
      while (i-- > 0)
        {
          GSRunLoopCtxt *c = [contexts objectAtIndex: i];

          if (c != self)
            { 
              [c endEvent: (void*)handle type: ET_HANDLE];
            }
	}
      /*
       * The watcher is still valid - so call its receivers
       * event handling method.
       */
      (*watcher->handleEvent)(watcher->receiver,
          eventSel, watcher->data, watcher->type,
          (void*)(gsaddr)handle, mode);
    }

  GSNotifyASAP();

  completed = YES;
  return YES;
}

@end

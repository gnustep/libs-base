#ifndef __RunLoop_h_OBJECTS_INCLUDE
#define __RunLoop_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <objects/NotificationDispatcher.h>
#include <objects/Bag.h>
#include <objects/Heap.h>
#include <Foundation/NSMapTable.h>
#include <sys/types.h>

@interface RunLoop : NSObject
{
  fd_set _fds;
  NSMapTable *_fd_2_object;
  Bag *_fd_objects;
  Heap *_timers;
  NotificationDispatcher *_dispatcher;
  Array *_queues;
}

- (void) addFileDescriptor: (int)fd
                invocation: invocation
		   forMode: (id <String>)mode;
- (void) removeFileDescriptor: (int)fd 
		      forMode: (id <String>)mode;

- (void) addTimer: timer forMode: (id <String>)mode;

- limitDateForMode: (id <String>)mode;
- (void) acceptInputForMode: (id <String>)mode
                 beforeDate: date;

- (void) run;
- (void) runUntilDate: limit_date;
- (BOOL) runOnceBeforeDate: date
		   forMode: (id <String>)mode;
- (BOOL) runMode: (id <String>)mode 
      beforeDate: limit_date;

+ (void) run;
+ (void) runUntilDate: date;

+ currentInstance;

@end


#endif /* __RunLoop_h_OBJECTS_INCLUDE */

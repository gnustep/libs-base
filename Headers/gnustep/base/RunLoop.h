#ifndef __RunLoop_h_GNUSTEP_BASE_INCLUDE
#define __RunLoop_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <gnustep/base/NotificationDispatcher.h>
#include <gnustep/base/Set.h>
#include <Foundation/NSMapTable.h>
#include <sys/types.h>

@interface RunLoop : NSObject
{
  id _current_mode;
  NSMapTable *_mode_2_timers;
  NSMapTable *_mode_2_in_ports;
  NSMapTable *_mode_2_fd_listeners;
  NSMapTable *_mode_2_fd_speakers;
}

- (void) addPort: port
         forMode: (NSString*)mode;
- (void) removePort: port
            forMode: (NSString*)mode;

- (void) addTimer: timer forMode: (NSString*)mode;

- limitDateForMode: (NSString*)mode;
- (void) acceptInputForMode: (NSString*)mode
                 beforeDate: date;
- (NSString*) currentMode;

- (void) run;
- (void) runUntilDate: limit_date;
- (BOOL) runOnceBeforeDate: date;
- (BOOL) runOnceBeforeDate: date forMode: (NSString*)mode;

+ (void) run;
+ (void) runUntilDate: date;
+ (void) runUntilDate: date forMode: (NSString*)mode;
+ (BOOL) runOnceBeforeDate: date;
+ (BOOL) runOnceBeforeDate: date forMode: (NSString*)mode;

+ currentInstance;
+ (NSString*) currentMode;

@end

/* Mode strings. */
extern id RunLoopDefaultMode;

/*
 *	GNUstep specific extensions to the RunLoop class
 *	xxx This interface will probably change.
 */

@protocol FdListening
- (void) readyForReadingOnFileDescriptor: (int)fd;
@end
@protocol FdSpeaking
- (void) readyForWritingOnFileDescriptor: (int)fd;
@end

@interface RunLoop (GNUstepExtensions)
/* Register an object (listener) to receive 'readyForReadingOnFileDescriptor:'
   message whenever the descriptor (fd) is readable. */
- (void) addReadDescriptor: (int)fd
		    object: (id <FdListening>)listener
		   forMode: (NSString*)mode;
/* Register an object (speaker) to receive 'readyForWritingOnFileDescriptor:'
   message whenever the descriptor (fd) is writable. */
- (void) addWriteDescriptor: (int)fd
		    object: (id <FdSpeaking>)speaker
		   forMode: (NSString*)mode;
- (void) removeReadDescriptor: (int)fd
		   forMode: (NSString*)mode;
- (void) removeWriteDescriptor: (int)fd
		   forMode: (NSString*)mode;
@end

/* xxx This interface will probably change. */
@interface NSObject (OptionalPortRunLoop)
/* If a InPort object responds to this, it is sent just before we are
   about to wait listening for input.
   This interface will probably change. */
- (void) getFds: (int*)fds count: (int*)count;
@end

#endif /* __RunLoop_h_GNUSTEP_BASE_INCLUDE */

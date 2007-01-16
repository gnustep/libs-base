#ifndef __GSRunLoopCtxt_h_GNUSTEP_BASE_INCLUDE
#define __GSRunLoopCtxt_h_GNUSTEP_BASE_INCLUDE

#include "config.h"
#include <Foundation/NSException.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSRunLoop.h>

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

#include "GNUstepBase/GSIArray.h"

#ifdef  HAVE_POLL
typedef struct{
  int   limit;
  short *index;
}pollextra;
#endif

@class NSString;
@class GSRunLoopWatcher;

@interface	GSRunLoopCtxt : NSObject
{
@public
  void		*extra;		/** Copy of the RunLoop ivar.		*/
  NSString	*mode;		/** The mode for this context.		*/
  GSIArray	performers;	/** The actions to perform regularly.	*/
  GSIArray	timers;		/** The timers set for the runloop mode */
  GSIArray	watchers;	/** The inputs set for the runloop mode */
  NSTimer	*housekeeper;	/** Housekeeping timer for loop.	*/
@private
#if	defined(__MINGW32__)
  NSMapTable    *handleMap;     
  NSMapTable	*winMsgMap;
#else
  NSMapTable	*_efdMap;
  NSMapTable	*_rfdMap;
  NSMapTable	*_wfdMap;
#endif
  GSIArray	_trigger;	// Watchers to trigger unconditionally.
  int		fairStart;	// For trying to ensure fair handling.
  BOOL		completed;	// To mark operation as completed.
#ifdef	HAVE_POLL
  unsigned int	pollfds_capacity;
  unsigned int	pollfds_count;
  struct pollfd	*pollfds;
#endif
}
- (void) endEvent: (void*)data
              for: (GSRunLoopWatcher*)watcher;
- (void) endPoll;
- (id) initWithMode: (NSString*)theMode extra: (void*)e;
- (BOOL) pollUntil: (int)milliseconds within: (NSArray*)contexts;
@end

@interface	NSRunLoop (Housekeeper)
- (void) _setHousekeeper: (NSTimer*)timer;
@end

#endif /* __GSRunLoopCtxt_h_GNUSTEP_BASE_INCLUDE */

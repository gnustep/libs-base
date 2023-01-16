#ifndef	INCLUDED_GSTIMEOUTSOURCE_H
#define	INCLUDED_GSTIMEOUTSOURCE_H

#import "common.h"
#import "GSDispatch.h"

/*
 * A helper class that wraps a libdispatch timer.
 *
 * Used to implement the timeout of `GSMultiHandle` and `GSEasyHandle`
 */
@interface GSTimeoutSource : NSObject
{
  dispatch_source_t  _timer;
  NSInteger          _timeoutMs;
  bool               _isSuspended;
}


- (instancetype) initWithQueue: (dispatch_queue_t)queue
                       handler: (dispatch_block_t)handler;

- (NSInteger) timeout;
- (void) setTimeout: (NSInteger)timeoutMs;

- (void) suspend;

- (void) cancel;

@end

#endif

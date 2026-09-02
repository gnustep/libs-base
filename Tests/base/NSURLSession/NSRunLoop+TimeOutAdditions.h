#import <Foundation/NSDate.h>
#import <Foundation/NSRunLoop.h>

@interface
NSRunLoop (TimeOutAdditions)
/* Run the run loop for a short slice.  Returns NO once deadline has passed,
 * so a caller waits with
 *
 *   while (<still waiting> && [rl runSliceUntil: deadline]) ;
 *
 * which states the condition without needing a block.
 */
- (BOOL)runSliceUntil:(NSDate *)deadline;
@end

@implementation
NSRunLoop (TimeOutAdditions)
- (BOOL)runSliceUntil:(NSDate *)deadline
{
  if ([deadline timeIntervalSinceNow] <= 0.0)
    {
      return NO;
    }
  ENTER_POOL
  [self runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  LEAVE_POOL
  return YES;
}
@end

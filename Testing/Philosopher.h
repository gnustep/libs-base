//
// Philosopher.h
//
// A class of hungry philosophers
//

#include <Foundation/NSLock.h>
#include <Foundation/NSThread.h>

// Conditions
#define NO_FOOD 1
#define FOOD_SERVED 2

@interface Philosopher : NSObject

{
  int chair;
}

// Instance methods
- (void)sitAtChair:(int)position;
- (int)chair;

@end

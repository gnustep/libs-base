//
// Philosopher.h
//
// A class of hungry philosophers
//

#include "Philosopher.h"

extern id forks[5];

@implementation Philosopher

// Instance methods
- (void)sitAtChair:(int)position
{
	int i;

	// Sit down
	chair = position;

	// Its a constant battle to feed yourself
	while (1)
	{
		// Get the fork to our left
		[forks[chair] lockWhenCondition:FOOD_SERVED];

		// Get the fork to our right
		[forks[(chair + 1) % 5] lockWhenCondition:FOOD_SERVED];

		// Start eating!
		printf("Philosopher %d can start eating.\n", chair);

		for (i = 0;i < 100000; ++i)
		{
			if ((i % 10000) == 0)
				printf("Philosopher %d is eating.\n", chair);
		}

		// Done eating
		printf("Philosopher %d is done eating.\n", chair);

		// Drop the fork to our left
		[forks[chair] unlock];

		// Drop the fork to our right
		[forks[(chair + 1) % 5] unlock];

		// Wait until we are hungry again
		for (i = 0;i < 1000000 * (chair + 1); ++i) ;
	}

	// We never get here, but this is what we should do
	[NSThread exit];
}

- (int)chair
{
	return chair;
}

@end
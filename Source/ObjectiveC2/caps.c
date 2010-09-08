#include "capabilities.h"
#include <stdint.h>

/**
 * Bitmask of all of the capabilities compiled into this version of the
 * runtime.
 */
static const int32_t caps =
	(1<<OBJC_CAP_EXCEPTIONS) |
	(1<<OBJC_CAP_SYNCRONIZE) |
	(1<<OBJC_CAP_PROPERTIES) |
	0;

int objc_test_capability(int x)
{
	if (x >= 32) { return 0; }
	if (caps & (1<<x)) { return 1; }
	return 0;
}

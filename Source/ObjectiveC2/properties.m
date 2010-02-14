#include "runtime.h"

// Subset of NSObject interface needed for properties.
@interface NSObject {}
- (id)retain;
- (id)copy;
- (id)autorelease;
- (void)release;
@end

id objc_getProperty(id obj, SEL _cmd, ptrdiff_t offset, BOOL isAtomic)
{
	if (isAtomic)
	{
		@synchronized(obj) {
			return objc_getProperty(obj, _cmd, offset, NO);
		}
	}
	char *addr = (char*)obj;
	addr += offset;
	id ret = *(id*)addr;
	return [[ret retain] autorelease];
}

void objc_setProperty(id obj, SEL _cmd, ptrdiff_t offset, id arg, BOOL isAtomic, BOOL isCopy)
{
	if (isAtomic)
	{
		@synchronized(obj) {
			objc_setProperty(obj, _cmd, offset, arg, NO, isCopy);
			return;
		}
	}
	if (isCopy)
	{
		arg = [arg copy];
	}
	else
	{
		arg = [arg retain];
	}
	char *addr = (char*)obj;
	addr += offset;
	id old = *(id*)addr;
	*(id*)addr = arg;
	[old release];
}

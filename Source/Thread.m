
#if defined(NeXT)

#elif defined(MACH)

#elif defined(sun) && defined(svr4)

@implementation Thread
@end
@implementation Lock
@end

#else
#error Threads not available for this system.
#endif

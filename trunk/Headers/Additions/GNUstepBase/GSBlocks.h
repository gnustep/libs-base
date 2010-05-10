
/* Define the has_feature pseudo-macro for GCC. */
#ifndef __has_feature 
#define __has_feature(x) 0
#endif

#if __has_feature(blocks)
/**
 * Defines a block type.  Will work whether or not the compiler natively
 * supports blocks.
 */
#define DEFINE_BLOCK_TYPE(name, retTy, argTys, ...) \
typedef retTy(^name)(argTys, ## __VA_ARGS__)
/**
 * Calls a block.  Works irrespective of whether the compiler supports blocks.
 */
#define CALL_BLOCK(block, args, ...) \
	block(args, ## __VA_ARGS__)
/* Fall-back versions for when the compiler doesn't have native blocks support.
 */
#else

#if (GCC_VERSION >= 3000)

#define DEFINE_BLOCK_TYPE(name, retTy, argTys, ...) \
	typedef struct {\
		void *isa;\
		int flags;\
		int reserved;\
		retTy (*invoke)(void*, argTys, ## __VA_ARGS__);\
	} *name
#define CALL_BLOCK(block, args, ...) \
	block->invoke(block, args, ## __VA_ARGS__)

#else /* GCC_VERSION >= 3000 */

#define DEFINE_BLOCK_TYPE(name, retTy, argTys, args...) \
	typedef struct {\
		void *isa;\
		int flags;\
		int reserved;\
		retTy (*invoke)(void*, argTys, args);\
	} *name
#define CALL_BLOCK(block, args...) \
	block->invoke(block, args)


#endif /* GCC_VERSION >= 3000 */

#endif


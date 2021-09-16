/*
 * Blocks Runtime
 */

#ifdef __cplusplus
#define BLOCKS_EXPORT extern "C"
#else
#define BLOCKS_EXPORT extern
#endif

// Testplant -- this workaround is temporary until we move to a newer libobjc on linux.
#ifndef __MINGW32__
BLOCKS_EXPORT void *_Block_copy(void *);
BLOCKS_EXPORT void _Block_release(void *);
BLOCKS_EXPORT const char *_Block_get_types(void*);

#define Block_copy(x) ((__typeof(x))_Block_copy((void *)(x)))
#define Block_release(x) _Block_release((void *)(x))
#else
// Testplant -- keep this part when moving to newer libobjc on linux.
BLOCKS_EXPORT void *_Block_copy(const void *);
BLOCKS_EXPORT void _Block_release(const void *);
BLOCKS_EXPORT const char *_Block_get_types(const void*);

#define Block_copy(x) ((__typeof(x))_Block_copy((const void *)(x)))
#define Block_release(x) _Block_release((const void *)(x))

#endif // __MINGW32__

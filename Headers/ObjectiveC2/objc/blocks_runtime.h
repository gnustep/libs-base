/*
 * Blocks Runtime
 */

#ifdef __cplusplus
#define BLOCKS_EXPORT extern "C"
#else
#define BLOCKS_EXPORT extern 
#endif

BLOCKS_EXPORT void *_Block_copy(void *);
BLOCKS_EXPORT void _Block_release(void *);
BLOCKS_EXPORT const char *_Block_get_types(void*);

#define Block_copy(x) ((__typeof(x))_Block_copy((void *)(x)))
#define Block_release(x) _Block_release((void *)(x))

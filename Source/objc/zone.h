#ifndef __zone_h_OBJECTS_INCLUDE
#define __zone_h_OBJECTS_INCLUDE

#include <stddef.h>

typedef struct _NXZone 
{
  void *(*realloc)(struct _NXZone *zonep, void *ptr, size_t size);
  void *(*malloc)(struct _NXZone *zonep, size_t size);
  void (*free)(struct _NXZone *zonep, void *ptr);
  void (*destroy)(struct _NXZone *zonep);
} NXZone;

#define NX_NOZONE  ((NXZone *)0)
#define NXZoneMalloc(zonep, size) ((*(zonep)->malloc)(zonep, size))
#define NXZoneRealloc(zonep, ptr, size) ((*(zonep)->realloc)(zonep, ptr, size))
#define NXZoneFree(zonep, ptr) ((*(zonep)->free)(zonep, ptr))
#define NXDestroyZone(zonep) ((*(zonep)->destroy)(zonep))

extern NXZone *NXDefaultMallocZone(void);
extern NXZone *NXCreateZone(size_t startSize, size_t granularity, int canFree);
extern NXZone *NXCreateChildZone(NXZone *parentZone, size_t startSize, 
				 size_t granularity, int canFree);
extern void NXMergeZone(NXZone *zonep);
extern void *NXZoneCalloc(NXZone *zonep, size_t numElems, size_t byteSize);
extern NXZone *NXZoneFromPtr(void *ptr);
extern void NXZonePtrInfo(void *ptr);
extern void NXNameZone(NXZone *z, const char *name);
extern int NXMallocCheck(void);

#endif /* __zone_h_OBJECTS_INCLUDE */

#include <objc/zone.h>

NXZone *NXDefaultMallocZone(void)
{
  return NX_NOZONE;
}

NXZone *NXCreateZone(size_t startSize, size_t granularity, int canFree)
{
  return NX_NOZONE;
}

NXZone  *NXCreateChildZone(NXZone *parentZone, size_t startSize, size_t granularity, int canFree)
{
  return NX_NOZONE;
}

void NXMergeZone(NXZone *zonep)
{
  return;
}

void *NXZoneCalloc(NXZone *zonep, size_t numElems, size_t byteSize)
{
  return 0;
}

NXZone *NXZoneFromPtr(void *ptr)
{
  return NX_NOZONE;
}

void NXZonePtrInfo(void *ptr)
{
  return;
}

int NXMallocCheck(void)
{
  return 1;
}

void NXNameZone(NXZone *z, const char *name)
{
  return;
}

/* Zone memory management.
   Copyright (C) 1996, 1997  Free Software Foundation, Inc.
 
   Author: Yoo C. Chung <wacko@power1.snu.ac.kr>
   Date: September 1996
 
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

/* This uses some GCC specific extensions. But since the library is
   supposed to compile on GCC 2.7.2 (patched) or higher, and the only
   other Objective-C compiler I know of (other than NeXT's) is the
   StepStone compiler, which I haven't the foggiest idea why anyone
   would prefer it to GCC ;), it should be OK.
   
   This uses it's own routines with NSDefaultMallocZone() instead of
   using malloc() and friends.  But if that's a problem, then it's a
   trivial problem to fix (at least it should be).

   THe NSZone functions should be thread-safe.  But I haven't actually
   tested them in a multi-threaded environment.
   
   In a small block, every chunk has a size that is a multiple of CHUNK.
   A free chunk in a freeable zone looks like this:

   unsigned : front : size of chunk
               back : 0
   unsigned : front : position of next free chunk (0 if none)
               back : position of previous free chunk (0 if none)
   Unused memory
   unsigned : front : position of previous free chunk (0 if none)
               back : position of next free chunk (0 if none)
   unsigned : front : size of chunk
               back : 0
   
   A used chunk in a freeable zone looks like this.

   unsigned : front : size of chunk
               back : position of this chunk in block
   Memory that is actually used
   unsigned : front : size of chunk
               back : position of this chunk in block

   All sizes and positions are in units of bytes.

   The use of unsigned is probably a Bad Thing (tm).  This should
   still work on machines where sizeof(void*) != sizof(unsigned), but
   you wouldn't be able to allocate as much memory as you might be
   able to in one chunk, and it's kind of unelegant.  The DEC Alpha is
   such a machine (though in this case, a program that needs memory
   whose size can't fit in a 32 bit integer should really think about
   cutting down on its size, or at least divide the problem up).
   
   This assumes that sizeof(unsigned) is a multiple of two.  I don't
   think I'll have to worry too much about this assumption. */

#define NDEBUG /* Comment this out to turn on assertions. */

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <objc/thr.h>
#include <Foundation/NSException.h>
#include <Foundation/NSZone.h>

#define ONES (~0U)
#define BACK (ONES << (sizeof(unsigned)*4))
#define FRONT (ONES >> (sizeof(unsigned)*4))
#define FREEOVERHEAD (4*sizeof(unsigned))
#define USEDOVERHEAD (2*sizeof(unsigned))
#define CHUNK FREEOVERHEAD /* Minimum size of chunk. */
#define BLOCKHEAD roundupto(sizeof(BlockHeader), CHUNK)

typedef struct _ZoneTable ZoneTable;
typedef struct _BlockHeader BlockHeader;

struct _ZoneTable
{
  struct _ZoneTable *next;
  unsigned ident; /* Identifier for zone table, starts at 1. */
  unsigned count, size;
  NSZone zones[0];
};

struct _BlockHeader
{
  struct _BlockHeader *previous, *next;
  
  /* For small block, front is size, back is zone identifier, for big
     block and free block, the whole thing is size. The size includes
     the header. */
  unsigned size;
  
  /* For freeable zone, front is size of biggest free chunk, back is
     position of biggest free chunk (it's size of the block if none
     available). For non-freeable zone, position of free chunk (it's
     size of the block if none available). It's 0 for a big block. */
  unsigned free;
};

static unsigned bsize = 0; /* Minimum block size. */
static unsigned zunit; /* Number of zones in a zone table. */
static ZoneLock zonelock; /* Lock for zone tables. */
static ZoneLock blocklock; /* Lock for blocks. */
static BlockHeader *freeBlocks = NULL; /* Higher blocks come first. */
static BlockHeader *lastFree = NULL;
static NSZone defaultZone;
static ZoneTable *zones = NULL;
static ZoneTable *endzones = NULL;

/* Gets a block with size SIZE. SIZE must be a multiple of bsize.  The
   size given includes overhead.  Returns NULL if no block can be
   returned. */
static BlockHeader *getBlock(unsigned size);

static void initialize(void) __attribute((constructor));
  
static void releaseBlock(BlockHeader *block);
static void *getMemInBlock(BlockHeader *block, unsigned size);
static void insertFreeChunk(BlockHeader *block, void *chunk);

/* Get previously unused zone slot. Return NULL if no zone can be returned. */
static NSZone *getZone(void);

static void releaseZone(NSZone *zone); /* Mark zone slot as unused. */

/* Memory functions for freeable zones. */
static void *fmalloc(NSZone *zone, unsigned size);
static void *frealloc(NSZone *zone, void *ptr, unsigned size);
static void ffree(NSZone *zone, void *ptr);
static void frecycle(NSZone *zone);

/* Memory functions for non-freeable zones. */
static void *nmalloc(NSZone *zone, unsigned size);
static void *nrealloc(NSZone *zone, void *ptr, unsigned size);
static void nfree(NSZone *zone, void *ptr);
static void nrecycle(NSZone *zone);

/* Rounds N up to a multiple of BASE. */
static inline unsigned
roundupto(unsigned n, unsigned base)
{
  unsigned a = (n/base)*base;

  return (n-a)? a+base: n;
}

/* Return front half of N. */
static inline unsigned
splitfront(unsigned n)
{
  return n & FRONT;
}

/* Return back half of N. Expect this to be slower that splitfront(). */
static inline unsigned
splitback(unsigned n)
{
  return (n & BACK) >> (sizeof(unsigned)*4);
}

/* Check that back half of N is not zero. If so, return non-zero number. */
static inline unsigned
backnonzero(unsigned n)
{
  return n & BACK;
}

/* Set front half of n. Front must fit within half of an unsigned. */
static inline void
setfront(unsigned *n, unsigned front)
{
  assert(front <= FRONT);
  
  *n = (*n & BACK) | front;

  assert(splitfront(*n) == front);
}

/* Set back half of n. Back half must fit in half of an unsigned.
   Expect this to be slower than setfront(). */
static inline void
setback(unsigned *n, unsigned back)
{
  assert(back <= FRONT);
  
  *n = (*n & FRONT) | (back << (sizeof(unsigned)*4));

  assert(splitback(*n) == back);
}

/* Return unsigned integer such that front and back are set to the
   given numbers. The given numbers must fit within half of an
   unsigned. */
static inline unsigned
setfrontback(unsigned front, unsigned back)
{
  assert(front <= FRONT);
  assert(back <= FRONT);
  
  return front | (back << (sizeof(unsigned)*4));
}

/* Maximum size for blocks containing small chunks. */
static inline unsigned
maxsblock(void)
{
  return 1U << (sizeof(unsigned)*4-1);
}

/* Create mutex. */
static inline ZoneLock
makelock(void)
{
  return objc_mutex_allocate();
}

/* Destroy mutex. */
static inline void
destroylock(ZoneLock mutex)
{
  objc_mutex_deallocate(mutex);
}

/* Lock with MUTEX. */
static inline void
lock(ZoneLock mutex)
{
  /* The thought of a probable system call is rather unappealing, but
     what else can I do? */
  objc_mutex_lock(mutex);
}

/* Release the lock on MUTEX. */
static inline void
unlock(ZoneLock mutex)
{
  /* Like lock(), a probable system call is rather unappealing. */
  objc_mutex_unlock(mutex);
}

/* Get zone identifier for given zone. */
static inline unsigned
getZoneIdent(NSZone *zone)
{
  ZoneTable *table = zone->table;
  
  if (zone->table == NULL)
    return 0;
  return table->ident*zunit+(zone-table->zones);
}

static inline NSZone*
zoneWithIdent(unsigned ident)
{
  if (ident)
    {
      int i, a;
      ZoneTable *table = zones;

      for (i = a = ident/zunit; i > 1; i--)
	table = table->next;
      return table->zones+(ident-a*zunit);
    }
  return &defaultZone;
}

static inline BlockHeader*
addBBlock(BlockHeader *list, BlockHeader *block)
{
  block->previous = NULL;
  block->next = list;
  if (list != NULL)
    list->previous = block;
  return block;
}

static inline BlockHeader*
addSBlock(BlockHeader *list, BlockHeader *block)
{
  block->previous = NULL;
  block->next = list;
  list->previous = block;
  return block;
}

static inline void
releaseSBlock(BlockHeader *block)
{
  if (block->next != NULL)
    block->next->previous = block->previous;
  if (block->previous != NULL)
    block->previous->next = block->next;
  block->size = splitfront(block->size);
  releaseBlock(block);
}

static inline void
releaseBBlock(BlockHeader *block)
{
  if (block->next != NULL)
    block->next->previous = block->previous;
  if (block->previous != NULL)
    block->previous->next = block->next;
  releaseBlock(block);
}

/* SIZE includes the overhead. */
static inline void
setFreeChunk(void *chunk, unsigned size, unsigned prev, unsigned next)
{
  unsigned tmp = setfrontback(size-USEDOVERHEAD, 0);
  unsigned *intp = chunk;

  assert(size%CHUNK == 0);
  
  *intp = tmp;
  *(intp+1) = setfrontback(next, prev);
  intp = (void*)intp+size;
  *(intp-1) = tmp;
  *(intp-2) = setfrontback(prev, next);
}

/* SIZE includes the overhead. */
static inline void
setUsedChunk(void *chunk, unsigned size, unsigned pos)
{
  unsigned n = setfrontback(size-USEDOVERHEAD, pos);
  unsigned *intp = chunk;

  assert(size%CHUNK == 0);
  
  *intp = n;
  intp = (void*)intp+size;
  *(intp-1) = n;
  return;
}

NSZone*
NSCreateZone(unsigned startSize, unsigned granularity, BOOL canFree)
{
  NSZone *zone;
  BlockHeader *block;

  initialize ();
  if ((startSize == 0) || (startSize > maxsblock()))
    startSize = bsize;
  else
    startSize = roundupto(startSize, bsize);
  if ((granularity == 0) || (granularity > maxsblock()))
    granularity = bsize;
  zone = getZone();
  if (zone == NULL)
    [NSException raise: NSMallocException
		 format: @"NSCreateZone(): Unable to obtain zone"];
  zone->sblocks = block = getBlock(startSize);
  if (block == NULL)
    {
      releaseZone(zone);
      [NSException raise: NSMallocException
		   format: @"NSCreateZone(): More memory unattainable"];
    }
  zone->granularity = roundupto(granularity, bsize);
  zone->name = nil;
  zone->bblocks = NULL;
  zone->lock = makelock();
  block->previous = block->next = NULL;
  block->size = setfrontback(startSize, getZoneIdent(zone));
  if (canFree)
    {
      zone->malloc = fmalloc;
      zone->realloc = frealloc;
      zone->free = ffree;
      zone->recycle = frecycle;
      block->free =
	setfrontback(startSize-(BLOCKHEAD+USEDOVERHEAD), BLOCKHEAD);
      setFreeChunk((void*)block+BLOCKHEAD, startSize-BLOCKHEAD, 0, 0);
    }
  else
    {
      zone->malloc = nmalloc;
      zone->realloc = nrealloc;
      zone->free = nfree;
      zone->recycle = nrecycle;
      block->free = BLOCKHEAD;
    }
  return zone;
}

NSZone*
NSDefaultMallocZone(void)
{
  initialize ();
  return &defaultZone;
}

NSZone*
NSZoneFromPointer(void *pointer)
{
  unsigned *intp;
  BlockHeader *block;

  intp = pointer-sizeof(unsigned);
  block = (void*)intp-splitback(*intp);
  if (block->free)
    return zoneWithIdent(splitback(block->size));
  else
    {
      BlockHeader *aBlock = defaultZone.bblocks;
      NSZone *zone, *endzone;
      ZoneTable *table;

      while (aBlock != NULL)
	{
	  if (aBlock == block)
	    return &defaultZone;
	  aBlock = aBlock->next;
	}
      table = zones;
      while (table != NULL)
	{
	  zone = table->zones;
	  endzone = zone+table->size;
	  while (zone < endzone)
	    {
	      if (zone->table != NULL)
		{
		  aBlock = zone->bblocks;
		  while (aBlock != NULL)
		    {
		      if (aBlock == block)
			return zone;
		      aBlock = aBlock->next;
		    }
		}
	      zone++;
	    }
	  table = table->next;
	}
    }
  return NULL; /* No zone containing pointer found. */
}
      
inline void*
NSZoneMalloc(NSZone *zone, unsigned size)
{
  return (zone->malloc)(zone, size);
}

void*
NSZoneCalloc(NSZone *zone, unsigned numElems, unsigned numBytes)
{
  return memset((zone->malloc)(zone, numElems*numBytes), 0, numElems*numBytes);
}

inline void*
NSZoneRealloc(NSZone *zone, void *pointer, unsigned size)
{
  return (zone->realloc)(zone, pointer, size);
}

inline void
NSRecycleZone(NSZone *zone)
{
  (zone->recycle)(zone);
}

inline void
NSZoneFree(NSZone *zone, void *pointer)
{
  (zone->free)(zone, pointer);
}

void
NSSetZoneName (NSZone *zone, NSString *name)
{
  zone->name = [name copy];
}

NSString*
NSZoneName (NSZone *zone)
{
  return zone->name;
}

void
NSZonePtrInfo(void *ptr)
{
  /* FIXME: Implement this. */
  fprintf(stderr, "NSZonePtrInfo() not implemented yet!\n");
}

BOOL
NSMallocCheck(void)
{
  /* FIXME: Implement this. */
  fprintf(stderr, "NSMallocCheck() not implemented yet!\n");
  abort();
  return NO;
}

static void
initialize(void)
{
  static int initialize_done = 0;
  BlockHeader *block;

  if (initialize_done)
    return;
  initialize_done = 1;

  bsize = NSPageSize();
  zunit = (bsize-sizeof(ZoneTable))/sizeof(NSZone);
  zonelock = makelock();
  blocklock = makelock();
  defaultZone.lock = makelock();
  defaultZone.granularity = bsize;
  defaultZone.malloc = fmalloc;
  defaultZone.realloc = frealloc;
  defaultZone.free = ffree;
  defaultZone.recycle = NULL;
  defaultZone.name = nil;
  defaultZone.table = NULL;
  defaultZone.bblocks =  NULL;
  block = defaultZone.sblocks = getBlock(bsize);
  if (block == NULL)
    {
      fprintf(stderr, "Unable to allocate memory for default zone.\n");
      abort(); /* No point surviving if we can't even use the default zone. */
    }
  block->previous = block->next = NULL;
  block->size = setfrontback(bsize, 0);
  block->free = setfrontback(bsize-BLOCKHEAD-USEDOVERHEAD, BLOCKHEAD);
  setFreeChunk((void*)block+BLOCKHEAD, bsize-BLOCKHEAD, 0, 0);
}

static BlockHeader*
getBlock(unsigned size)
{
  BlockHeader *block;

  assert(size%bsize == 0);
  
  lock(blocklock);
  block = freeBlocks;
  while ((block != NULL) && (block->size < size))
    block = block->next;
  if (block == NULL)
    block = NSAllocateMemoryPages(size);
  else if (block->size != size)
    {
      BlockHeader *splitblock;
      
      splitblock = (void*)block+size;
      splitblock->previous = block->previous;
      splitblock->next = block->next;
      splitblock->size = block->size-size;
      if (block->next != NULL)
	block->next->previous = splitblock;
      if (block->previous != NULL)
	block->previous->next = splitblock;
    }
  unlock(blocklock);
  return block;
}

static void
releaseBlock(BlockHeader *block)
{
  BlockHeader *aBlock;

  lock(blocklock);
  aBlock = freeBlocks;
  while ((aBlock != NULL) && (aBlock > block))
    aBlock = aBlock->next;
  if (aBlock == NULL)
    {
      if (lastFree == NULL)
	{
	  lastFree = freeBlocks = block;
	  block->previous = aBlock->next = NULL;
	}
      else if ((void*)block+block->size == (void*)lastFree)
	{
	  block->size += lastFree->size;
	  block->previous = lastFree->previous;
	  block->next = NULL;
	  if (block->previous != NULL)
	    block->previous->next = block;
	  lastFree = block;
	}
      else
	{
	  block->previous = lastFree;
	  block->next = NULL;
	  lastFree->next = block;
	  lastFree = block;
	}
    }
  else
    {
      if (aBlock->previous == NULL)
	{
	  freeBlocks = block;
	  block->next = aBlock;
	  block->previous = NULL;
	  aBlock->previous = block;
	}
      else if ((void*)block+block->size == aBlock->previous)
	{
	  block->size += aBlock->previous->size;
	  block->previous = aBlock->previous->previous;
	  block->next = aBlock;
	  if (block->previous != NULL)
	    block->previous->next = block;
	  aBlock->previous = block;
	}
      if ((void*)aBlock+aBlock->size == block)
	aBlock->size += block->size;
    }
  unlock(blocklock);
}

static void*
getMemInBlock(BlockHeader *block, unsigned size)
{
  unsigned chunksize = roundupto(size+USEDOVERHEAD, CHUNK);
  unsigned *intp, *intp2;

  assert(splitfront(block->free) >= size+USEDOVERHEAD);
  
  intp = (void*)block+splitback(block->free);
  intp2 = (void*)block+splitfront(*(intp+1));
  if ((void*)intp2 != (void*)block)
    {
      setFreeChunk(intp2, splitfront(*intp2)+USEDOVERHEAD,
		   0, splitfront(*(intp2+1)));
      block->free =
	setfrontback(splitfront(*intp2), (void*)intp2-(void*)block);
    }
  else
    block->free = setfrontback(0, splitfront(block->size));
  if (splitfront(*intp)+USEDOVERHEAD != chunksize)
    {
      setFreeChunk((void*)intp+chunksize,
		   (splitfront(*intp)+USEDOVERHEAD)-chunksize, 0, 0);
      insertFreeChunk(block, (void*)intp+chunksize);
    }
  setUsedChunk(intp, chunksize, (void*)intp-(void*)block);
  return intp+1;
}

static void
insertFreeChunk(BlockHeader *block, void *chunk)
{
  unsigned *intp = chunk;

  assert((void*)chunk < (void*)block+splitfront(block->size));

  if (splitfront(block->free) == 0)
    {
      block->free = setfrontback(splitfront(*intp), chunk-(void*)block);
      setFreeChunk(chunk, splitfront(*intp)+USEDOVERHEAD, 0, 0);
    }
  else
    {
      unsigned *intp2 = (void*)block+splitback(block->free);
      unsigned *intp3 = NULL;

      while (((void*)intp2 != (void*)block)
	     && (splitfront(*intp) < splitfront(*intp2)))
	{
	  intp3 = intp2;
	  intp2 = (void*)block+splitfront(*(intp2+1));
	}
      if (intp3 == NULL)
	{
	  unsigned pos = chunk-(void*)block;
	  
	  setFreeChunk(intp2, splitfront(*intp2)+USEDOVERHEAD,
		       pos, splitfront(*(intp2+1)));
	  setFreeChunk(chunk, splitfront(*intp)+USEDOVERHEAD,
		       0, (void*)intp2-(void*)block);
	  block->free = setfrontback(splitfront(*intp), pos);
	}
      else if ((void*)intp2 == (void*)block)
	{
	  setFreeChunk(intp3, splitfront(*intp3)+USEDOVERHEAD,
		       splitback(*(intp3+1)), chunk-(void*)block);
	  setFreeChunk(chunk, splitfront(*intp)+USEDOVERHEAD,
		       (void*)intp3-(void*)block, 0);
	}
      else
	{
	  unsigned pos = chunk-(void*)block;
	  
	  setFreeChunk(intp2, splitfront(*intp2)+USEDOVERHEAD,
		       pos, splitfront(*(intp2+1)));
	  setFreeChunk(intp3, splitfront(*intp3)+USEDOVERHEAD,
		       splitback(*(intp3+1)), pos);
	  setFreeChunk(chunk, splitfront(*intp)+USEDOVERHEAD,
		       (void*)intp3-(void*)block, (void*)intp2-(void*)block);
	}
    }
}

static NSZone*
getZone(void)
{
  NSZone *zone;
  ZoneTable *table = zones;

  lock(zonelock);
  while ((table != NULL) && (table->count == zunit))
    table = table->next;
  if (table == NULL)
    {
      table = NSAllocateMemoryPages(bsize);
      if (table == NULL)
	zone = NULL;
      else
	{
	  table->size = table->count = 1;
	  table->next = zones;
	  if (zones == NULL)
	    {
	      zones = table;
	      table->ident = 1;
	    }
	  else
	    {
	      endzones->next = table;
	      table->ident = endzones->ident+1;
	    }
	  endzones = table;
	  table->next = NULL;
	  zone = table->zones;
	}
    }
  else
    {
      if (table->size == zunit)
	{
	  zone = table->zones;
	  while (zone->table != NULL)
	    zone++;
	}
      else
	{
	  zone = table->zones+table->size;
	  table->size++;
	}
      table->count++;
    }
  zone->table = table;
  unlock(zonelock);
  return zone;
}

static void
releaseZone(NSZone *zone)
{
  lock(zonelock);
  ((ZoneTable*)zone->table)->count--;
  zone->table = NULL;
  unlock(zonelock);
  return;
}

static void*
fmalloc(NSZone *zone, unsigned size)
{
  unsigned *intp;
  BlockHeader *block;
  void *ptr;

  lock(zone->lock);
  if (size+BLOCKHEAD+USEDOVERHEAD > maxsblock())
    {
      unsigned realSize = roundupto(size+BLOCKHEAD+USEDOVERHEAD, bsize);
      
      block = getBlock(realSize);
      if (block == NULL)
	{
	  unlock(zone->lock);
	  [NSException raise: NSMallocException
		       format: @"NSZoneMalloc(): Unable to get memory"];
	}
      block->size = realSize;
      block->free = 0;
      zone->bblocks = addBBlock(zone->bblocks, block);
      intp = (void*)block+BLOCKHEAD;
      *intp = setfrontback(0, BLOCKHEAD);
      ptr = intp+1;
    }
  else
    {
      block = zone->sblocks;
      while ((block != NULL) && (splitfront(block->free) < size+USEDOVERHEAD))
	block = block->next;
      if (block == NULL)
	{
	  unsigned chunk = roundupto(size+USEDOVERHEAD, CHUNK);
	  unsigned tmp, total;
      
	  total = roundupto(size+BLOCKHEAD+USEDOVERHEAD, zone->granularity);
	  block = getBlock(total);
	  if (block == NULL)
	    {
	      unlock(zone->lock);
	      [NSException raise: NSMallocException
			   format: @"NSZoneMalloc(): Unable to get memory"];
	    }
	  zone->sblocks = addSBlock(zone->sblocks, block);
	  tmp = total-chunk-BLOCKHEAD-USEDOVERHEAD;
	  block->size = setfrontback(total, getZoneIdent(zone));
	  block->free = setfrontback(tmp, chunk+BLOCKHEAD);
	  setUsedChunk((void*)block+BLOCKHEAD, chunk, BLOCKHEAD);
	  setFreeChunk((void*)block+(chunk+BLOCKHEAD), tmp+USEDOVERHEAD, 0, 0);
	  ptr = (void*)block+(BLOCKHEAD+sizeof(unsigned));
	}
      else
	ptr = getMemInBlock(block, size);
    }
  unlock(zone->lock);
  return ptr;
}

static void*
frealloc(NSZone *zone, void *ptr, unsigned size)
{
  /* FIXME: Implement this properly! */
  void *newptr;

  newptr = fmalloc(zone, size);
  memcpy(newptr, ptr, size);
  ffree(zone, ptr);
  return newptr;
}

static void
ffree(NSZone *zone, void *ptr)
{
  unsigned *intp;
  BlockHeader *block;

  if (ptr == NULL)
    return;
  lock(zone->lock);
  intp = ptr-sizeof(unsigned);
  block = (void*)intp-splitback(*intp);
  if (block->free)
    insertFreeChunk(block, intp);
  else
    {
      if (block->previous == NULL)
	zone->bblocks = block->next;
      else
	block->previous->next = block->next;
      if (block->next != NULL)
	block->next->previous = block->previous;
      releaseBBlock(block);
    }
  unlock(zone->lock);
  return;
}

static void
frecycle(NSZone *zone)
{
  BlockHeader *block, *nextblock;

  block = zone->bblocks;
  while (block != NULL)
    {
      nextblock = block->next;
      defaultZone.bblocks = addBBlock(defaultZone.bblocks, block);
      block = nextblock;
    }
  block = zone->sblocks;
  while (block != NULL)
    {
      nextblock = block->next;
      if (splitfront(block->size)
	  == splitfront(block->free)+BLOCKHEAD+USEDOVERHEAD)
	releaseSBlock(block);
      else
	defaultZone.sblocks = addSBlock(defaultZone.sblocks, block);
      block = nextblock;
    }
  [zone->name release];
  destroylock(zone->lock);
  releaseZone(zone);
  return;
}

static void*
nmalloc(NSZone *zone, unsigned size)
{
  unsigned *intp;
  BlockHeader *block;

  lock(zone->lock);
  if (size+BLOCKHEAD+USEDOVERHEAD > maxsblock())
    {
      unsigned realSize = roundupto(size+BLOCKHEAD+USEDOVERHEAD, bsize);

      block = getBlock(realSize);
      if (block == NULL)
	{
	  unlock(zone->lock);
	  [NSException raise: NSMallocException
		       format: @"NSZoneMalloc(): Unable to get memory"];
	}
      block->size = realSize;
      block->free = 0;
      zone->bblocks = addBBlock(zone->bblocks, block);
      intp = (void*)block+BLOCKHEAD;
      *intp = setfrontback(0, BLOCKHEAD);
    }
  else
    {
      block = zone->sblocks;
      if (size+sizeof(unsigned) > splitfront(block->size)-block->free)
	{
	  unsigned newsize;
	  BlockHeader *newblock;

	  newsize =
	    roundupto(size+USEDOVERHEAD+BLOCKHEAD, zone->granularity);
	  newblock = getBlock(newsize);
	  if (newblock == NULL)
	    {
	      unlock(zone->lock);
	      [NSException raise: NSMallocException
			   format: @"NSZoneMalloc(): Unable to get memory"];
	    }
	  newblock->size = setfrontback(newsize, getZoneIdent(zone));
	  newblock->free = roundupto(size+sizeof(unsigned), CHUNK)+BLOCKHEAD;
	  zone->sblocks = addSBlock(zone->sblocks, newblock);
	  intp = (void*)newblock+BLOCKHEAD;
	  *intp = setfrontback(0, BLOCKHEAD);
	}
      else
	{
	  intp = (void*)block+block->free;
	  *intp = (void*)intp-(void*)block;
	  block->free += roundupto(size+sizeof(unsigned), CHUNK);
	}
    }
  unlock(zone->lock);
  return intp+1;
}

static void*
nrealloc(NSZone *zone, void *ptr, unsigned size)
{
  [NSException raise: NSGenericException
	       format: @"Trying to reallocate memory in non-freeable zone"];
  return NULL;
}

static void
nfree(NSZone *zone, void *ptr)
{
  [NSException raise: NSGenericException
	       format: @"Trying to free memory in non-freeable zone"];
  return;
}

static void
nrecycle(NSZone *zone)
{
  BlockHeader *block;

  block = zone->sblocks;
  while (block != NULL)
    {
      releaseSBlock(block);
      block = block->next;
    }
  block = zone->bblocks;
  while (block != NULL)
    {
      releaseBBlock(block);
      block = block->next;
    }
  destroylock(zone->lock);
  [zone->name release];
  releaseZone(zone);
  return;
}

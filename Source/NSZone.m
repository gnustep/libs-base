/* Zone memory management. -*- Mode: ObjC -*-
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by: Yoo C. Chung <wacko@power1.snu.ac.kr>
   Date: January 1997

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */

/*  Design goals:

    - Allocation and deallocation should be reasonably effecient.

    - Finding the zone containing a given pointer should be very
    effecient, since objects in Objective-C use that information to
    deallocate themselves. */


/* Actual design:

   - All memory chunks allocated in a zone is preceded by a pointer to
   the zone.  This makes locating the zone containing the memory chunk
   extermemely fast.  However, this creates an additional 4 byte
   overhead for 32 bit machines (8 bytes on 64 bit machines!).

   - For freeable zones, a small linear buffer is used for
   deallocating and allocating.  Anything that can't go into the
   buffer then uses a more general purpose segregated fit algorithm
   after flushing the buffer.

   - For memory chunks in freeable zones, the pointer to the zone is
   preceded by the size, which also contains other information for
   boundary tags.  This adds 4 bytes for freeable zones, for a total
   of a minimum of 8 byte overhead for every memory chunk in the zone.

   - For nonfreeable zones, worst-like fit is used.  This is OK since
   we don't have to worry about memory fragmentation. */

/* Other information:

   - This uses some GCC specific extensions. But since the library is
   supposed to compile on GCC 2.7.2 (patched) or higher, and the only
   other Objective-C compiler I know of (other than NeXT's) is the
   StepStone compiler, which I haven't the foggiest idea why anyone
   would prefer it to GCC ;), it should be OK.

   - This uses its own routines for NSDefaultMallocZone() instead of
   using malloc() and friends.  Making it use them would be a somewhat
   intractable problem if we want to have a fast NSZoneFromPointer(),
   since we would have to search all the zones to see if they
   contained the pointer.

   - These functions should be thread safe, but I haven't really
   tested them extensively in multithreaded cases. */

/* Define to turn off assertions. */
#define NDEBUG

#include <gnustep/base/preface.h>
#include <assert.h>
#include <stddef.h>
#include <string.h>
#include <objc/thr.h>
#include <Foundation/NSException.h>
#include <Foundation/NSPage.h>
#include <Foundation/NSString.h>
#include <Foundation/NSZone.h>

#define ALIGN 8 /* Alignment.  FIXME: Make this portable. */
#define MINGRAN 256 /* Minimum granularity. */
#define DEFBLOCK 16384 /* Default granularity. */
#define BUFFER 16 /* Buffer size */
#define MAX_SEG 16 /* Segregated list size. */
#define ZPTRSZ sizeof(NSZone*) /* Size of zone pointers. */
#define SZSZ sizeof(size_t) /* Size of size_t. */

/* Information bits in size. */
#define INUSE 0x01 /* Current chunk in use. */
#define PREVUSE 0x02 /* Previous chunk in use. */

/* Bits to mask off to get size. */
#define SIZE_BITS (INUSE | PREVUSE)

/* Minimum chunk size for freeable zones. */
#define MINCHUNK roundupto(2*(SZSZ+ZPTRSZ), ALIGN)

/* Size of block headers in freeable zones. */
#define FF_HEAD (roundupto(sizeof(ff_block)+ZPTRSZ+SZSZ, MINCHUNK)-ZPTRSZ-SZSZ)

/* Size of block headers in nonfreeable zones. */
#define NF_HEAD (roundupto(sizeof(nf_block)+ZPTRSZ, ALIGN)-ZPTRSZ)

#define CLTOSZ(n) ((n)*MINCHUNK) /* Converts classes to sizes. */

typedef struct _ffree_free_link ff_link;
typedef struct _nfree_block_struct nf_block;
typedef struct _ffree_block_struct ff_block;
typedef struct _ffree_NSZone_struct ffree_NSZone;
typedef struct _nfree_NSZone_struct nfree_NSZone;


/* Links for free lists. */
struct _ffree_free_link
{
  size_t *prev, *next;
};

/* Header for blocks in nonfreeable zones. */
struct _nfree_block_struct
{
  struct _nfree_block_struct *next;
  size_t size; // Size of block
  size_t top; // Position of next memory chunk to allocate
};

/* Header for blocks in freeable zones. */
struct _ffree_block_struct
{
  struct _ffree_block_struct *next;
  size_t size;
};

/* NSZone structure for freeable zones. */
struct _ffree_NSZone_struct
{
  NSZone common;
  ff_block *blocks; // Linked list of blocks
  size_t *segheadlist[MAX_SEG]; // Segregated list, holds heads
  size_t *segtaillist[MAX_SEG]; // Segregated list, holds tails
  size_t bufsize; // Buffer size
  size_t size_buf[BUFFER]; // Buffer holding sizes
  size_t *ptr_buf[BUFFER]; // Buffer holding pointers to chunks
};

/* NSZone structure for nonfreeable zones. */
struct _nfree_NSZone_struct
{
  NSZone common;
  /* Linked list of blocks in decreasing order of free space,
     except maybe for the first block. */
  nf_block *blocks;
};

/* Initializing functions. */
static void initialize (void) __attribute__ ((constructor));
static void become_threaded (void);

/* Rounds up N to nearest multiple of BASE. */
static inline size_t roundupto (size_t n, size_t base);

/* Dummy lock, unlock function. */
static void dummy_lock (objc_mutex_t mutex);

/* Memory management functions for freeable zones. */
static void* fmalloc (NSZone *zone, size_t size);
static void* frealloc (NSZone *zone, void *ptr, size_t size);
static void ffree (NSZone *zone, void *ptr);
static void frecycle (NSZone *zone);

static inline size_t segindex (size_t size);
static void* get_chunk (ffree_NSZone *zone, size_t size);
static void take_chunk (ffree_NSZone *zone, size_t *chunk);
static void put_chunk (ffree_NSZone *zone, size_t *chunk);
static inline void add_buf (ffree_NSZone *zone, size_t *chunk);
static void flush_buf (ffree_NSZone *zone);

/* Memory management functions for nonfreeable zones. */
static void* nmalloc (NSZone *zone, size_t size);
static void nrecycle (NSZone *zone);

/* Saves callback when mulithreading starts. */
static objc_thread_callback thread_callback;

/* Mutex function pointers. */
static void (*lock)(objc_mutex_t mutex) = dummy_lock;
static void (*unlock)(objc_mutex_t mutex) = dummy_lock;

/* Error message. */
static NSString *outmemstr = @"Out of memory";

static ffree_NSZone default_zone =
{
  { fmalloc, frealloc, ffree, NULL, DEFBLOCK, (objc_mutex_t)0, nil },
  NULL,
  {
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
  },
  {
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
  },
  0,
  { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
  {
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
  }  
};

/* Default zone.  Name is hopelessly long so that no one will ever
   want to use it. ;) */
NSZone* __nszone_private_hidden_default_zone = (NSZone*)(&default_zone);

/* It would be nice if the Objective-C runtime had something like
   pthread's PTHREAD_MUTEX_INITIALIZER macro.  Then we wouldn't need
   to do any initialization at all.  Oh well. */
static void
initialize (void)
{
  thread_callback = objc_set_thread_callback(become_threaded);
}

static void
become_threaded (void)
{
  if (thread_callback != NULL)
    thread_callback();
  default_zone.common.lock = objc_mutex_allocate();
}

static inline size_t
roundupto (size_t n, size_t base)
{
  size_t a = (n/base)*base;

  return (n-a)? (a+base): n;
}

static void
dummy_lock (objc_mutex_t mutex)
{
  // Do nothing.
}

/* Search the buffer to see if there is any memory chunks large enough
   to satisfy request using first fit.  If the memory chunk found has
   a size exactly equal to the one requested, remove it from the buffer
   and return it.  If not, cut off a chunk that does match the size
   and return it.  If there is no chunk large enough in the buffer,
   get a chunk from the general purpose allocator that uses segregated
   fit.  Since a chunk in the buffer is not freed in the general purpose
   allocator, the headers are as if it is still in use. */
static void*
fmalloc (NSZone *zone, size_t size)
{
  size_t i = 0;
  size_t chunksize = roundupto(size+SZSZ+ZPTRSZ, MINCHUNK);
  ffree_NSZone *zptr = (ffree_NSZone*)zone;
  size_t bufsize;
  size_t *size_buf = zptr->size_buf;
  size_t **ptr_buf = zptr->ptr_buf;
  size_t *chunkhead;

  if (size == 0)
    return NULL;
  lock(zone->lock);
  bufsize = zptr->bufsize;
  while ((i < bufsize) && (chunksize > size_buf[i]))
    i++;
  if (i < bufsize)
    /* Use memory chunk in buffer. */
    {
      if (size_buf[i] == chunksize)
	/* Exact fit. */
	{
	  zptr->bufsize--;
	  bufsize = zptr->bufsize;
	  chunkhead = ptr_buf[i];
	  size_buf[i] = size_buf[bufsize];
	  ptr_buf[i] = ptr_buf[bufsize];

	  assert(*chunkhead & INUSE);
	  assert((*chunkhead & ~SIZE_BITS)%MINCHUNK == 0);
	}
      else
	/* Break off chunk. */
	{
	  NSZone **zoneptr; // Pointer to zone preceding memory chunk

	  chunkhead = ptr_buf[i];

	  assert(*chunkhead & INUSE);
	  assert((*chunkhead & ~SIZE_BITS)%MINCHUNK == 0);
	  assert(chunksize < size_buf[i]);
	  
	  size_buf[i] -= chunksize;
	  ptr_buf[i] = (void*)chunkhead+chunksize;
	  *(ptr_buf[i]) = size_buf[i] | PREVUSE | INUSE;
	  zoneptr = (NSZone**)(ptr_buf[i]+1);
	  *zoneptr = zone;
	  *chunkhead = chunksize | (*chunkhead & PREVUSE) | INUSE;
	}
    }
  else
    /* Get memory from segregate fit allocator. */
    {
      flush_buf(zptr);
      chunkhead = get_chunk(zptr, chunksize);
      if (chunkhead == NULL)
	{
	  unlock(zone->lock);
	  [NSException raise: NSMallocException format: outmemstr];
	}

      assert(*chunkhead & INUSE);
      assert((*chunkhead & ~SIZE_BITS)%MINCHUNK == 0);
    }
  unlock(zone->lock);
  return (void*)chunkhead+(SZSZ+ZPTRSZ);
}

/* If PTR == NULL, then it's the same as ordinary memory allocation.
   If a smaller size than it originally had is requested, shrink the
   chunk.  If a larger size is requested, check if there is enough
   space after it.  If there isn't enough space, get a new chunk and
   move it there, releasing the original.  The space before the chunk
   should also be checked, but I'll leave this to a later date. */
static void*
frealloc (NSZone *zone, void *ptr, size_t size)
{
  size_t realsize;
  size_t chunksize = roundupto(size+SZSZ+ZPTRSZ, MINCHUNK);
  ffree_NSZone *zptr = (ffree_NSZone*)zone;
  size_t *chunkhead, *slack;
  NSZone **zoneptr; // Zone pointer preceding memory chunk.

  if (size == 0)
    {
      ffree(zone, ptr);
      return NULL;
    }
  if (ptr == NULL)
    return fmalloc(zone, size);
  lock(zone->lock);
  chunkhead = ptr-(SZSZ+ZPTRSZ);
  realsize = *chunkhead & ~SIZE_BITS;

  assert(*chunkhead & INUSE);
  assert(realsize%MINCHUNK == 0);
  
  if (chunksize < realsize)
    /* Make chunk smaller. */
    {
      slack = (void*)chunkhead+chunksize;
      *slack = (realsize-chunksize) | PREVUSE | INUSE;
      zoneptr = (NSZone**)(slack+1);
      *zoneptr = zone;
      add_buf(zptr, slack);
      *chunkhead = chunksize | (*chunkhead & PREVUSE) | INUSE;
    }
  else if (chunksize > realsize)
    {
      size_t nextsize;
      size_t *nextchunk, *farchunk;

      nextchunk = (void*)chunkhead+realsize;
      nextsize = *nextchunk & ~SIZE_BITS;

      assert(nextsize%MINCHUNK == 0);
      
      if (!(*nextchunk & INUSE) && (nextsize+realsize >= chunksize))
	/* Expand to next chunk. */
	{
	  take_chunk(zptr, nextchunk);
	  if (nextsize+realsize == chunksize)
	    {
	      farchunk = (void*)nextchunk+nextsize;
	      *farchunk |= PREVUSE;
	    }
	  else
	    {
	      slack = (void*)chunkhead+chunksize;
	      *slack = ((nextsize+realsize)-chunksize) | PREVUSE;
	      put_chunk(zptr, slack);
	    }
	  *chunkhead = chunksize | (*chunkhead & PREVUSE) | INUSE;
	}
      else
	/* Get new chunk and copy. */
	{
	  size_t *newchunk;
	  
	  newchunk = get_chunk(zptr, chunksize);
	  if (newchunk == NULL)
	    {
	      unlock(zone->lock);
	      [NSException raise: NSMallocException format: outmemstr];
	    }
	  memcpy((void*)newchunk+SZSZ+ZPTRSZ, (void*)chunkhead+SZSZ+ZPTRSZ,
		 chunksize-SZSZ-ZPTRSZ);
	  add_buf(zptr, chunkhead);
	  chunkhead = newchunk;
	}
      /* FIXME: consider other cases where we can get more memory. */
    }
  unlock(zone->lock);
  return (void*)chunkhead+(SZSZ+ZPTRSZ);
}

/* Frees memory chunk by simply adding it to the buffer. */
static void
ffree (NSZone *zone, void *ptr)
{
  lock(zone->lock);
  add_buf((ffree_NSZone*)zone, ptr-(SZSZ+ZPTRSZ));
  unlock(zone->lock);
}

/* Recycle the zone.  We should give objects that are still alive to
   the default zone by looking into each block and resetting the zone
   pointers in each used memory chunks and adding the free chunks to
   the default zone's buffer, but I'm lazy, so I'll do it later.  For
   now, we just release all the blocks.

   No locking is done.  Making sure that nothing tries to use this
   zone when and after it's recycled should be the programmer's
   responsibility. */
static void
frecycle (NSZone *zone)
{
  ffree_NSZone *zptr = (ffree_NSZone*)zone;
  ff_block *block = zptr->blocks;
  ff_block *nextblock;

  objc_mutex_deallocate(zone->lock);
  while (block != NULL)
    {
      nextblock = block->next;
      ffree(NSDefaultMallocZone(), block);
      block = nextblock;
      /* FIXME: should return live objects to default zone. */
    }
  if (zone->name != nil)
    [zone->name release];
  ffree(NSDefaultMallocZone(), zptr);
}

static inline size_t
segindex (size_t size)
{
  assert(size%MINCHUNK == 0);


  if (size < CLTOSZ(8))
    return size/MINCHUNK;
  else if (size < CLTOSZ(16))
    return 7;
  else if (size < CLTOSZ(32))
    return 8;
  else if (size < CLTOSZ(64))
    return 9;
  else if (size < CLTOSZ(128))
    return 10;
  else if (size < CLTOSZ(256))
    return 11;
  else if (size < CLTOSZ(512))
    return 12;
  else if (size < CLTOSZ(1024))
    return 13;
  else if (size < CLTOSZ(2048))
    return 14;
  else
    return 15;
}

/* Look through the segregated list with first fit to find a memory
   chunk.  If one is not found, get more memory. */
static void*
get_chunk (ffree_NSZone *zone, size_t size)
{
  size_t class = segindex(size);
  size_t *chunk = zone->segheadlist[class];
  NSZone **zoneptr; // Zone pointer preceding memory chunk

  assert(size%MINCHUNK == 0);
  
  while ((chunk != NULL) && ((*chunk & ~SIZE_BITS) < size))
    chunk = ((ff_link*)(chunk+1))->next;
  if (chunk == NULL)
    /* Get more memory. */
    {
      class++;
      while ((class < MAX_SEG) && (zone->segheadlist[class] == NULL))
	class++;
      if (class == MAX_SEG)
	/* Absolutely no memory in segregated list. */
	{
	  size_t blocksize;
	  ff_block *block;

	  blocksize = roundupto(size+FF_HEAD+SZSZ+ZPTRSZ, zone->common.gran);
	  if (zone == &default_zone)
	    {
	      block = NSAllocateMemoryPages(blocksize);
	      if (block == NULL)
		return NULL;
	    }
	  else
	    {
	      /* Any clean way to make gcc shut up here? */
	      NS_DURING
		block = fmalloc(NSDefaultMallocZone(), blocksize);
	      NS_HANDLER
		return NULL;
	      NS_ENDHANDLER
	    }
	  assert(block != NULL);
	  
	  block->size = blocksize;
	  block->next = zone->blocks;
	  zone->blocks = block;
	  chunk = (void*)block+(blocksize-SZSZ-ZPTRSZ);
	  if (FF_HEAD+size+SZSZ+ZPTRSZ < blocksize)
	    {
	      *chunk = INUSE;
	      chunk = (void*)block+(FF_HEAD+size);
	      *chunk = (blocksize-size-FF_HEAD-SZSZ-ZPTRSZ) | PREVUSE;
	      put_chunk(zone, chunk);

	      assert((*chunk & ~SIZE_BITS)%MINCHUNK == 0);
	    }
	  else
	    *chunk = PREVUSE | INUSE;
	  chunk = (void*)block+FF_HEAD;
	}
      else
	{
	  size_t *slack;

	  chunk = zone->segheadlist[class];

	  assert(class < MAX_SEG);
	  assert(!(*chunk & INUSE));
	  assert(*chunk & PREVUSE);
	  assert(size < (*chunk & ~SIZE_BITS));
	  assert((*chunk & ~SIZE_BITS)%MINCHUNK == 0);
	  
	  take_chunk(zone, chunk);
	  slack = (void*)chunk+size;
	  *slack = ((*chunk & ~SIZE_BITS)-size) | PREVUSE;
	  put_chunk(zone, slack);
	}
    }
  else
    {
      size_t chunksize = *chunk & ~SIZE_BITS;

      assert(chunksize%MINCHUNK == 0);
      assert(!(*chunk & INUSE));
      assert(*chunk & PREVUSE);
      assert(*(size_t*)((void*)chunk+chunksize) & INUSE);
      
      take_chunk(zone, chunk);
      if (chunksize > size)
	{
	  size_t *slack;
	  
	  slack = (void*)chunk+size;
	  *slack = (chunksize-size) | PREVUSE;
	  put_chunk(zone, slack);
	}
      else
	{
	  size_t *nextchunk = (void*)chunk+chunksize;

	  assert(!(*nextchunk & PREVUSE));
	  assert(chunksize == size);
	  
	  *nextchunk |= PREVUSE;
	}
    }
  *chunk = size | PREVUSE | INUSE;
  zoneptr = (NSZone**)(chunk+1);
  *zoneptr = (NSZone*)zone;
  return chunk;
}

/* Take the given chunk out of the free list.  No headers are set. */
static void
take_chunk (ffree_NSZone *zone, size_t *chunk)
{
  size_t size = *chunk & ~SIZE_BITS;
  size_t class = segindex(size);
  ff_link *otherlink;
  ff_link *links = (ff_link*)(chunk+1);

  assert(size%MINCHUNK == 0);
  assert(!(*chunk & INUSE));
  assert(*chunk & PREVUSE);
  
  if (links->prev == NULL)
    zone->segheadlist[class] = links->next;
  else
    {
      otherlink = (ff_link*)(links->prev+1);
      otherlink->next = links->next;
    }
  if (links->next == NULL)
    zone->segtaillist[class] = links->prev;
  else
    {
      otherlink = (ff_link*)(links->next+1);
      otherlink->prev = links->prev;
    }
}

/* Add the given chunk to the segregated list.  The header to the
   chunk must be set appropriately, but the tailer is set here. */
static void
put_chunk (ffree_NSZone *zone, size_t *chunk)
{
  size_t size = *chunk & ~SIZE_BITS;
  size_t class = segindex(size);
  size_t *tailer = (void*)chunk+(size-SZSZ);
  ff_link *links = (ff_link*)(chunk+1);

  assert(size%MINCHUNK == 0);
  assert(!(*chunk & INUSE));
  assert(*chunk & PREVUSE);
  
  *tailer = size;
  if (zone->segtaillist[class] == NULL)
    {
      assert(zone->segheadlist[class] == NULL);
      
      zone->segheadlist[class] = zone->segtaillist[class] = chunk;
      links->prev = links->next = NULL;
    }
  else
    {
      ff_link *prevlink = (ff_link*)(zone->segtaillist[class]+1);
      
      assert(zone->segheadlist[class] != NULL);

      links->next = NULL;
      links->prev = zone->segtaillist[class];
      prevlink->next = chunk;
      zone->segtaillist[class] = chunk;
    }
}

/* Add the given pointer to the buffer.  If the buffer becomes full,
   flush it.  The given pointer must always be one that points to used
   memory. */
static inline void
add_buf (ffree_NSZone *zone, size_t *chunk)
{
  size_t bufsize = zone->bufsize;

  assert(bufsize < BUFFER);
  assert(*chunk & INUSE);
  assert((*chunk & ~SIZE_BITS)%MINCHUNK == 0);
  
  zone->bufsize++;
  zone->size_buf[bufsize] = *chunk & ~SIZE_BITS;
  zone->ptr_buf[bufsize] = chunk;
  if (bufsize == BUFFER-1)
    flush_buf(zone);
}

/* Flush buffers.  All coalescing is done here. */
static void
flush_buf (ffree_NSZone *zone)
{
  size_t i, size;
  size_t bufsize = zone->bufsize;
  size_t *chunk, *nextchunk;
  size_t *size_buf = zone->size_buf;
  size_t **ptr_buf = zone->ptr_buf;

  assert(bufsize <= BUFFER);
  
  for (i = 0; i < bufsize; i++)
    {
      size = size_buf[i];
      chunk = ptr_buf[i];

      assert((*chunk & ~SIZE_BITS) == size);
      assert(*chunk & INUSE);

      nextchunk = (void*)chunk+size;
      if (!(*chunk & PREVUSE))
	/* Coalesce with previous chunk. */
	{
	  size_t prevsize = *(chunk-1);

	  assert(prevsize%MINCHUNK == 0);

	  size += prevsize;
	  chunk = (void*)chunk-prevsize;

	  assert(!(*chunk & INUSE));
	  assert(*chunk & PREVUSE);
	  assert((*chunk & ~SIZE_BITS) == prevsize);
	  
	  take_chunk(zone, chunk);
	}
      if (!(*nextchunk & INUSE))
	/* Coalesce with next chunk. */
	{
	  size_t nextsize = *nextchunk & ~SIZE_BITS;

	  assert(chunksize%MINCHUNK == 0);
	  assert(*nextchunk & PREVUSE);
	  assert(!(*nextchunk & INUSE));
	  assert((void*)chunk+chunksize == nextchunk);
	  
	  take_chunk(zone, nextchunk);
	  size += nextsize;
	}
      *chunk = size | PREVUSE;
      put_chunk(zone, chunk);
      nextchunk = (void*)chunk+size;
      *nextchunk &= ~PREVUSE;
      
      assert((*chunk & ~SIZE_BITS)%MINCHUNK == 0);
      assert(!(*chunk & INUSE));
      assert(*chunk & PREVUSE);
      assert(*nextchunk & INUSE);
      assert(!(*nextchunk & PREVUSE));
    }
  zone->bufsize = 0;
}

/* If the first block in block list has enough space, use that space.
   Otherwise, sort the block list in decreasing free space order (only
   the first block needs to be put in its appropriate place since
   the rest of the list is already sorted).  Then check if the first
   block has enough space for the request.  If it does, use it.  If it
   doesn't, get more memory from the default zone, since none of the
   other blocks in the block list could have enough memory. */
static void*
nmalloc (NSZone *zone, size_t size)
{
  nfree_NSZone *zptr = (nfree_NSZone*)zone;
  size_t top;
  size_t chunksize = roundupto(size+ZPTRSZ, ALIGN);
  NSZone **chunkhead;

  lock(zone->lock);
  top = zptr->blocks->top;
  /* No need to worry about (block == NULL), since a nonfreeable zone
     always starts with a block. */
  if (zptr->blocks->size-top >= chunksize)
    {
      chunkhead = (void*)(zptr->blocks)+top;
      *chunkhead = zone;
      zptr->blocks->top += chunksize;
    }
  else
    {
      size_t freesize = zptr->blocks->size-top;
      nf_block *block, *preblock;

      /* First, get the block list in decreasing free size order. */
      preblock = NULL;
      block = zptr->blocks;
      while ((block->next != NULL)
	     && (freesize < block->next->size-block->next->top))
	{
	  preblock = block;
	  block = block->next;
	}
      if (preblock != NULL)
	{
	  preblock->next = zptr->blocks;
	  zptr->blocks = zptr->blocks->next;
	  preblock->next->next = block;
	}
      if (zptr->blocks->size-zptr->blocks->top < chunksize)
	/* Get new block. */
	{
	  size_t blocksize = roundupto(size+NF_HEAD, zone->gran);
	  nf_block *block;

	  /* Any clean way to make gcc shut up here? */
	  NS_DURING
	    block = fmalloc(NSDefaultMallocZone(), blocksize);
	  NS_HANDLER
	    unlock(zone->lock);
	    [localException raise];
	  NS_ENDHANDLER
	  block->next = zptr->blocks;
	  block->size = blocksize;
	  block->top = NF_HEAD;
	  zptr->blocks = block;
	}
      chunkhead = (void*)block+zptr->blocks->top;
      *chunkhead = zone;
      zptr->blocks->top += chunksize;
    }
  unlock(zone->lock);
  return chunkhead+1;
}

/* Return the blocks to the default zone, then deallocate mutex, and
   then release zone name if it exists.

   No locking is done because I don't think someone would use a zone
   when they're going to recycle it.  If they do that, it's a
   programming error. */
static void
nrecycle (NSZone *zone)
{
  nf_block *nextblock;
  nf_block *block = ((nfree_NSZone*)zone)->blocks;

  objc_mutex_deallocate(zone->lock);
  while (block != NULL)
    {
      nextblock = block->next;
      ffree(NSDefaultMallocZone(), block);
      block = nextblock;
    }
  if (zone->name != nil)
    [zone->name release];
  ffree(NSDefaultMallocZone(), zone);
}

NSZone*
NSCreateZone (size_t start, size_t gran, BOOL canFree)
{
  size_t i, startsize, granularity;

  if (start > 0)
    startsize = roundupto(start, MINGRAN);
  else
    startsize = MINGRAN;
  if (gran > 0)
    granularity = roundupto(gran, MINGRAN);
  else
    granularity = MINGRAN;
  if (canFree)
    {
      ff_block *block;
      ffree_NSZone *zone;
      size_t *header, *tailer;
      NSZone **zoneptr;

      zone = fmalloc(NSDefaultMallocZone(), sizeof(ffree_NSZone));
      zone->common.malloc = fmalloc;
      zone->common.realloc = frealloc;
      zone->common.free = ffree;
      zone->common.recycle = frecycle;
      zone->common.gran = granularity;
      zone->common.lock = objc_mutex_allocate();
      zone->common.name = nil;
      for (i = 0; i < MAX_SEG; i++)
	{
	  zone->segheadlist[i] = NULL;
	  zone->segtaillist[i] = NULL;
	}
      zone->bufsize = 0;
      NS_DURING
	zone->blocks = block = fmalloc(NSDefaultMallocZone(), startsize);
      NS_HANDLER
	objc_mutex_dealloc(zone->common.lock);
        ffree(NSDefaultMallocZone(), zone);
        [localException raise];
      NS_ENDHANDLER
      block->next = NULL;
      block->size = startsize;
      header = (void*)block+FF_HEAD;
      *header = (startsize-FF_HEAD-SZSZ-ZPTRSZ) | PREVUSE | INUSE;
      zoneptr = (NSZone**)(header+1);
      *zoneptr = (NSZone*)zone;
      tailer = (void*)block+(startsize-SZSZ-ZPTRSZ);
      *tailer = INUSE | PREVUSE;
      add_buf(zone, header);
      return (NSZone*)zone;
    }
  else
    {
      nf_block *block;
      nfree_NSZone *zone;

      zone = fmalloc(NSDefaultMallocZone(), sizeof(nfree_NSZone));
      zone->common.malloc = nmalloc;
      zone->common.realloc = NULL;
      zone->common.free = NULL;
      zone->common.recycle = nrecycle;
      zone->common.gran = granularity;
      zone->common.lock = objc_mutex_allocate();
      zone->common.name = nil;
      NS_DURING
	zone->blocks = block = fmalloc(NSDefaultMallocZone(), startsize);
      NS_HANDLER
	objc_mutex_deallocate(zone->common.lock);
        ffree(NSDefaultMallocZone(), zone);
	[localException raise];
      NS_ENDHANDLER
      block->next = NULL;
      block->size = startsize;
      block->top = NF_HEAD;
      return (NSZone*)zone;
    }
}

inline NSZone*
NSDefaultMallocZone (void)
{
  return __nszone_private_hidden_default_zone;
}

inline NSZone*
NSZoneFromPointer (void *ptr)
{
  return *((NSZone**)ptr-1);
}

inline void*
NSZoneMalloc (NSZone *zone, size_t size)
{
  return (zone->malloc)(zone, size);
}

void*
NSZoneCalloc (NSZone *zone, size_t elems, size_t bytes)
{
  return memset(NSZoneMalloc(zone, elems*bytes), 0, elems*bytes);
}

inline void*
NSZoneRealloc (NSZone *zone, void *ptr, size_t size)
{
  return (zone->realloc)(zone, ptr, size);
}

inline void
NSRecycleZone (NSZone *zone)
{
  (zone->recycle)(zone);
}

inline void
NSZoneFree (NSZone *zone, void *ptr)
{
  (zone->free)(zone, ptr);
}

void
NSSetZoneName (NSZone *zone, NSString *name)
{
  lock(zone->lock);
  if (zone->name != nil)
    [zone->name release];
  if (name == nil)
    zone->name = nil;
  else
    zone->name = [name copy];
  unlock(zone->lock);
}

inline NSString*
NSZoneName (NSZone *zone)
{
  return zone->name;
}

BOOL
NSZoneMemInUse (void *ptr)
{
  return (*(size_t*)(ptr-ZPTRSZ-SZSZ)) & INUSE;
}

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

    - Allocation and deallocation should be reasonably efficient.

    - Finding the zone containing a given pointer should be reasonably
    efficient, since objects in Objective-C use that information to
    deallocate themselves. */


/* Actual design:

   - All memory chunks allocated in a zone is preceded by a pointer to
   the zone.  This makes locating the zone containing the memory chunk
   extremely fast.  However, this creates an additional 4 byte
   overhead for 32 bit machines (8 bytes on 64 bit machines!).

   - The default zone uses objc_malloc() and friends.  We assume that
   they're thread safe and that they return NULL if we're out of
   memory (they currently don't, unfortunately, so this is a FIXME).
   We also need to prepend a zone pointer.
   
   - For freeable zones, a small linear buffer is used for
   deallocating and allocating.  Anything that can't go into the
   buffer then uses a more general purpose segregated fit algorithm
   after flushing the buffer.

   - For memory chunks in freeable zones, the pointer to the zone is
   preceded by the size, which also contains other information for
   boundary tags.  This adds 4 bytes for freeable zones, for a total
   of a minimum of 8 byte overhead for every memory chunk in the zone
   (assuming we're on a 32 bit machine).

   - For nonfreeable zones, worst-like fit is used.  This is OK since
   we don't have to worry about memory fragmentation. */

/* Other information:

   - This uses some GCC specific extensions.  But since the library is
   supposed to compile on GCC 2.7.2.1 (patched) or higher, and the
   only other Objective-C compiler I know of (other than NeXT's, which
   is based on GCC as far as I know) is the StepStone compiler, which
   I haven't the foggiest idea why anyone would prefer it to GCC ;),
   it should be OK.

   - We cannot interchangeably use malloc() and friends (or
   objc_malloc() and friends) for memory allocated from zones if we
   want a fast NSZoneFromPointer(), since we would have to search all
   the zones to see if they contained the pointer.  We could
   accomplish this if we abandon the current scheme of finding zone
   pointers and use a centralized table, which would also probably
   save space, though it would be slower.

   - If a garbage collecting malloc is used for objc_malloc(), then
   that garbage collector must be able to mark from interior pointers,
   since the actual memory returned to the user in the default zone is
   offset from the memory returned from objc_malloc().
   
   - These functions should be thread safe, but I haven't really
   tested them extensively in multithreaded cases. */


/* Define to turn off assertions. */
#define NDEBUG


#include <gnustep/base/preface.h>
#include <assert.h>
#include <stddef.h>
#include <string.h>
#include <objc/objc-api.h>
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
typedef struct _ffree_zone_struct ffree_zone;
typedef struct _nfree_zone_struct nfree_zone;


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
struct _ffree_zone_struct
{
  NSZone common;
  objc_mutex_t lock;
  ff_block *blocks; // Linked list of blocks
  size_t *segheadlist[MAX_SEG]; // Segregated list, holds heads
  size_t *segtaillist[MAX_SEG]; // Segregated list, holds tails
  size_t bufsize; // Buffer size
  size_t size_buf[BUFFER]; // Buffer holding sizes
  size_t *ptr_buf[BUFFER]; // Buffer holding pointers to chunks
};

/* NSZone structure for nonfreeable zones. */
struct _nfree_zone_struct
{
  NSZone common;
  objc_mutex_t lock;
  /* Linked list of blocks in decreasing order of free space,
     except maybe for the first block. */
  nf_block *blocks;
};


/* Rounds up N to nearest multiple of BASE. */
static inline size_t roundupto (size_t n, size_t base);

/* Default zone functions for default zone. */
static void* default_malloc (NSZone *zone, size_t size);
static void* default_realloc (NSZone *zone, void *ptr, size_t size);
static void default_free (NSZone *zone, void *ptr);
static void default_recycle (NSZone *zone);
static BOOL default_check (NSZone *zone);
static struct NSZoneStats default_stats (NSZone *zone);

/* Memory management functions for freeable zones. */
static void* fmalloc (NSZone *zone, size_t size);
static void* frealloc (NSZone *zone, void *ptr, size_t size);
static void ffree (NSZone *zone, void *ptr);
static void frecycle (NSZone *zone);
static BOOL fcheck (NSZone *zone);
static struct NSZoneStats fstats (NSZone *zone);

static inline size_t segindex (size_t size);
static void* get_chunk (ffree_zone *zone, size_t size);
static void take_chunk (ffree_zone *zone, size_t *chunk);
static void put_chunk (ffree_zone *zone, size_t *chunk);
static inline void add_buf (ffree_zone *zone, size_t *chunk);
static void flush_buf (ffree_zone *zone);

/* Memory management functions for nonfreeable zones. */
static void* nmalloc (NSZone *zone, size_t size);
static void nrecycle (NSZone *zone);
static void* nrealloc (NSZone *zone, void *ptr, size_t size);
static void nfree (NSZone *zone, void *ptr);
static BOOL ncheck (NSZone *zone);
static struct NSZoneStats nstats (NSZone *zone);


static NSZone default_zone =
{
  default_malloc, default_realloc, default_free, default_recycle,
  default_check, default_stats, DEFBLOCK, @"default"
};

/* Default zone.  Name is hopelessly long so that no one will ever
   want to use it. ;) */
NSZone* __nszone_private_hidden_default_zone = &default_zone;


static inline size_t
roundupto (size_t n, size_t base)
{
  size_t a = (n/base)*base;

  return (n-a)? (a+base): n;
}

static void*
default_malloc (NSZone *zone, size_t size)
{
  NSZone **mem;

  mem = objc_malloc(ZPTRSZ+size);
  if (mem == NULL)
    [NSException raise: NSMallocException
                 format: @"Default zone has run out of memory"];
  *mem = zone;
  return mem+1;
}

static void*
default_realloc (NSZone *zone, void *ptr, size_t size)
{
  NSZone **mem = ptr-ZPTRSZ;

  mem = objc_realloc(mem, size+ZPTRSZ);
  if ((size != 0) && (mem == NULL))
    [NSException raise: NSMallocException
                 format: @"Default zone has run out of memory"];
  return mem+1;
}

static void
default_free (NSZone *zone, void *ptr)
{
  objc_free(ptr-ZPTRSZ);
}

static void
default_recycle (NSZone *zone)
{
  /* Recycle the default zone?  Thou hast got to be kiddin'. */
  [NSException raise: NSGenericException
               format: @"Trying to recycle default zone"];
}

static BOOL
default_check (NSZone *zone)
{
  /* We can't check memory managed by objc_malloc(). */
  [NSException raise: NSGenericException format: @"Not implemented"];
  return NO;
}

static struct NSZoneStats
default_stats (NSZone *zone)
{
  struct NSZoneStats dummy;
  
  /* We can't obtain statistics from the memory managed by objc_malloc(). */
  [NSException raise: NSGenericException format: @"Not implemented"];
  return dummy;
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
  ffree_zone *zptr = (ffree_zone*)zone;
  size_t bufsize;
  size_t *size_buf = zptr->size_buf;
  size_t **ptr_buf = zptr->ptr_buf;
  size_t *chunkhead;

  if (size == 0)
    return NULL;
  objc_mutex_lock(zptr->lock);
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
          objc_mutex_unlock(zptr->lock);
          if (zone->name != nil)
            [NSException raise: NSMallocException
                         format: @"Zone %s has run out of memory",
                         [zone->name cStringNoCopy]];
          else
            [NSException raise: NSMallocException
                         format: @"Out of memory"];
        }

      assert(*chunkhead & INUSE);
      assert((*chunkhead & ~SIZE_BITS)%MINCHUNK == 0);
    }
  objc_mutex_unlock(zptr->lock);
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
  ffree_zone *zptr = (ffree_zone*)zone;
  size_t *chunkhead, *slack;
  NSZone **zoneptr; // Zone pointer preceding memory chunk.

  if (size == 0)
    {
      ffree(zone, ptr);
      return NULL;
    }
  if (ptr == NULL)
    return fmalloc(zone, size);
  chunkhead = ptr-(SZSZ+ZPTRSZ);
  objc_mutex_lock(zptr->lock);
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
              objc_mutex_unlock(zptr->lock);
              if (zone->name != nil)
                [NSException raise: NSMallocException
                             format: @"Zone %s has run out of memory",
                             [zone->name cStringNoCopy]];
              else
                [NSException raise: NSMallocException
                             format: @"Out of memory"];
            }
          memcpy((void*)newchunk+SZSZ+ZPTRSZ, (void*)chunkhead+SZSZ+ZPTRSZ,
                 realsize-SZSZ-ZPTRSZ);
          add_buf(zptr, chunkhead);
          chunkhead = newchunk;
        }
      /* FIXME: consider other cases where we can get more memory. */
    }
  objc_mutex_unlock(zptr->lock);
  return (void*)chunkhead+(SZSZ+ZPTRSZ);
}

/* Frees memory chunk by simply adding it to the buffer. */
static void
ffree (NSZone *zone, void *ptr)
{
  objc_mutex_lock(((ffree_zone*)zone)->lock);
  add_buf((ffree_zone*)zone, ptr-(SZSZ+ZPTRSZ));
  objc_mutex_unlock(((ffree_zone*)zone)->lock);
}

/* Recycle the zone.  According to OpenStep, we need to return live
   objects to the default zone, but there is no easy way to return
   them, especially since the default zone may have been customized.
   So not returning memory to the default zone is a feature, not a
   bug (or so I think). */
static void
frecycle (NSZone *zone)
{
  ffree_zone *zptr = (ffree_zone*)zone;
  ff_block *block = zptr->blocks;
  ff_block *nextblock;

  objc_mutex_deallocate(zptr->lock);
  while (block != NULL)
    {
      nextblock = block->next;
      objc_free(block);
      block = nextblock;
    }
  if (zone->name != nil)
    [zone->name release];
  objc_free(zptr);
}

/* Check integrity of a freeable zone.  Doesn't have to be
   particularly efficient. */
static BOOL
fcheck (NSZone *zone)
{
  size_t i;
  ffree_zone *zptr = (ffree_zone*)zone;
  ff_block *block;
  size_t *chunk;
  
  objc_mutex_lock(zptr->lock);
  /* Check integrity of each block the zone owns. */
  block = zptr->blocks;
  while (block != NULL)
    {
      size_t blocksize, pos;
      size_t *nextchunk;

      blocksize = block->size;
      pos = FF_HEAD;
      while (pos < blocksize-(SZSZ+ZPTRSZ))
        {
          size_t chunksize;

          chunk = (void*)block+pos;
          chunksize = *chunk & ~SIZE_BITS;
          nextchunk = (void*)chunk+chunksize;
          if (*chunk & INUSE)
            /* Check whether this is a valid used chunk. */
            {
              NSZone **zoneptr;

              zoneptr = (NSZone**)(chunk+1);
              if ((*zoneptr != zone) || !(*nextchunk & PREVUSE))
                goto inconsistent;
            }
          else
            /* Check whether this is a valid free chunk. */
            {
              size_t *footer;

              footer = nextchunk-1;
              if ((*footer != chunksize) || (*nextchunk & PREVUSE))
                goto inconsistent;
            }
          pos += chunksize;
        }
      chunk = (void*)block+pos;
      /* Check whether the block ends properly. */
      if (((*chunk & ~SIZE_BITS) != 0) || !(*chunk & INUSE))
        goto inconsistent;
      block = block->next;
    }
  /* Check the integrity of the segregated list. */
  for (i = 0; i < MAX_SEG; i++)
    {
      chunk = zptr->segheadlist[i];
      while (chunk != NULL)
        {
          size_t *nextchunk;

          nextchunk = ((ff_link*)(chunk+1))->next;
          /* Isn't this one ugly if statement? */
          if ((*chunk & INUSE)
              || (segindex(*chunk & ~SIZE_BITS) != i)
              || ((nextchunk != NULL)
                  && (chunk != ((ff_link*)(nextchunk+1))->prev))
              || ((nextchunk == NULL) && (chunk != zptr->segtaillist[i])))
            goto inconsistent;
          chunk = nextchunk;
        }
    }
  /* Check the buffer. */
  if (zptr->bufsize >= BUFFER)
    goto inconsistent;
  for (i = 0; i < zptr->bufsize; i++)
    {
      chunk = zptr->ptr_buf[i];
      if ((zptr->size_buf[i] != (*chunk & ~SIZE_BITS)) || !(*chunk & INUSE))
        goto inconsistent;
    }
  objc_mutex_unlock(zptr->lock);
  return YES;

inconsistent: // Jump here if an inconsistency was found.
  objc_mutex_unlock(zptr->lock);
  return NO;
}

/* Obtain statistics about the zone.  Doesn't have to be particularly
   efficient. */
static struct NSZoneStats
fstats (NSZone *zone)
{
  size_t i;
  struct NSZoneStats stats;
  ffree_zone *zptr = (ffree_zone*)zone;
  ff_block *block;

  stats.bytes_total = 0;
  stats.chunks_used = 0;
  stats.bytes_used = 0;
  stats.chunks_free = 0;
  stats.bytes_free = 0;
  objc_mutex_lock(zptr->lock);
  block = zptr->blocks;
  /* Go through each block. */
  while (block != NULL)
    {
      size_t blocksize;
      size_t *chunk;

      blocksize = block->size;
      stats.bytes_total += blocksize;
      chunk = (void*)block+FF_HEAD;
      while ((void*)chunk < (void*)block+(blocksize-ZPTRSZ-SZSZ))
        {
          size_t chunksize;

          chunksize = *chunk & ~SIZE_BITS;
          if (*chunk & INUSE)
            {
              stats.chunks_used++;
              stats.bytes_used += chunksize;
            }
          else
            {
              stats.chunks_free++;
              stats.bytes_free += chunksize;
            }
          chunk = (void*)chunk+chunksize;
        }
      block = block->next;
    }
  /* Go through buffer. */
  for (i = 0; i < zptr->bufsize; i++)
    {
      stats.chunks_used--;
      stats.chunks_free++;
      stats.bytes_used -= zptr->size_buf[i];
      stats.bytes_free += zptr->size_buf[i];
    }
  objc_mutex_unlock(zptr->lock);
  /* Remove overhead. */
  stats.bytes_used -= (SZSZ+ZPTRSZ)*stats.chunks_used;
  return stats;
}

/* Calculate the which segregation class a certain size should be
   in. */
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
get_chunk (ffree_zone *zone, size_t size)
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
          block = objc_malloc(blocksize);
          if (block == NULL)
            return NULL;

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
take_chunk (ffree_zone *zone, size_t *chunk)
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
put_chunk (ffree_zone *zone, size_t *chunk)
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
   memory (i.e. chunks with headers that declare them as used). */
static inline void
add_buf (ffree_zone *zone, size_t *chunk)
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
flush_buf (ffree_zone *zone)
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
  nfree_zone *zptr = (nfree_zone*)zone;
  size_t top;
  size_t chunksize = roundupto(size+ZPTRSZ, ALIGN);
  NSZone **chunkhead;

  if (size == 0)
    return NULL;
  objc_mutex_lock(zptr->lock);
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
          size_t blocksize = roundupto(chunksize+NF_HEAD, zone->gran);

          block = objc_malloc(blocksize);
          if (block == NULL)
            {
              objc_mutex_unlock(zptr->lock);
              if (zone->name != nil)
                [NSException raise: NSMallocException
                             format: @"Zone %s has run out of memory",
                             [zone->name cStringNoCopy]];
              else
                [NSException raise: NSMallocException
                             format: @"Out of memory"];
            }
          block->next = zptr->blocks;
          block->size = blocksize;
          block->top = NF_HEAD;
          zptr->blocks = block;
        }
      chunkhead = (void*)block+zptr->blocks->top;
      *chunkhead = zone;
      zptr->blocks->top += chunksize;
    }
  objc_mutex_unlock(zptr->lock);
  return chunkhead+1;
}

/* Return the blocks to the default zone, then deallocate mutex, and
   then release zone name if it exists. */
static void
nrecycle (NSZone *zone)
{
  nf_block *nextblock;
  nf_block *block = ((nfree_zone*)zone)->blocks;

  objc_mutex_deallocate(((nfree_zone*)zone)->lock);
  while (block != NULL)
    {
      nextblock = block->next;
      objc_free(block);
      block = nextblock;
    }
  if (zone->name != nil)
    [zone->name release];
  objc_free(zone);
}

static void*
nrealloc (NSZone *zone, void *ptr, size_t size)
{
  if (zone->name != nil)
    [NSException raise: NSGenericException
                 format: @"Trying to reallocate in nonfreeable zone %s",
                 [zone->name cStringNoCopy]];
  else
    [NSException raise: NSGenericException
                 format: @"Trying to reallocate in nonfreeable zone"];
  return NULL; // Useless return
}

static void
nfree (NSZone *zone, void *ptr)
{
  if (zone->name != nil)
    [NSException raise: NSGenericException
                 format: @"Trying to free memory from nonfreeable zone %s",
                 [zone->name cStringNoCopy]];
  else
    [NSException raise: NSGenericException
                 format: @"Trying to free memory from nonfreeable zone"];
}

/* Check integrity of a nonfreeable zone.  Doesn't have to
   particularly efficient. */
static BOOL
ncheck (NSZone *zone)
{
  nfree_zone *zptr = (nfree_zone*)zone;
  nf_block *block;

  objc_mutex_lock(zptr->lock);
  block = zptr->blocks;
  while (block != NULL)
    {
      if (block->size < block->top)
        {
          objc_mutex_unlock(zptr->lock);
          return NO;
        }
      block = block->next;
    }
  /* FIXME: Do more checking? */
  objc_mutex_unlock(zptr->lock);
  return YES;
}

/* Return statistics for a nonfreeable zone.  Doesn't have to
   particularly efficient. */
static struct NSZoneStats
nstats (NSZone *zone)
{
  struct NSZoneStats stats;
  nfree_zone *zptr = (nfree_zone*)zone;
  nf_block *block;

  stats.bytes_total = 0;
  stats.chunks_used = 0;
  stats.bytes_used = 0;
  stats.chunks_free = 0;
  stats.bytes_free = 0;
  objc_mutex_lock(zptr->lock);
  block = zptr->blocks;
  while (block != NULL)
    {
      size_t *chunk;
      
      stats.bytes_total += block->size;
      chunk = (void*)block+NF_HEAD;
      while ((void*)chunk < (void*)block+block->top)
        {
          stats.chunks_used++;
          stats.bytes_used += *chunk;
          chunk = (void*)chunk+(*chunk);
        }
      if (block->size != block->top)
        {
          stats.chunks_free++;
          stats.bytes_free += block->size-block->top;
        }
      block = block->next;
    }
  objc_mutex_unlock(zptr->lock);
  stats.bytes_used -= ZPTRSZ*stats.chunks_used;
  return stats;
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
      ffree_zone *zone;
      size_t *header, *tailer;
      NSZone **zoneptr;

      zone = objc_malloc(sizeof(ffree_zone));
      if (zone == NULL)
        [NSException raise: NSMallocException
                     format: @"No memory to create zone"];
      zone->common.malloc = fmalloc;
      zone->common.realloc = frealloc;
      zone->common.free = ffree;
      zone->common.recycle = frecycle;
      zone->common.check = fcheck;
      zone->common.stats = fstats;
      zone->common.gran = granularity;
      zone->common.name = nil;
      zone->lock = objc_mutex_allocate();
      for (i = 0; i < MAX_SEG; i++)
        {
          zone->segheadlist[i] = NULL;
          zone->segtaillist[i] = NULL;
        }
      zone->bufsize = 0;
      zone->blocks = objc_malloc(startsize);
      if (zone->blocks == NULL)
        {
          objc_mutex_deallocate(zone->lock);
          objc_free(zone);
          [NSException raise: NSMallocException
                       format: @"No memory to create zone"];
        }
      block = zone->blocks;
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
      nfree_zone *zone;

      zone = objc_malloc(sizeof(nfree_zone));
      if (zone == NULL)
        [NSException raise: NSMallocException
                     format: @"No memory to create zone"];
      zone->common.malloc = nmalloc;
      zone->common.realloc = nrealloc;
      zone->common.free = nfree;
      zone->common.recycle = nrecycle;
      zone->common.check = ncheck;
      zone->common.stats = nstats;
      zone->common.gran = granularity;
      zone->common.name = nil;
      zone->lock = objc_mutex_allocate();
      zone->blocks = objc_malloc(startsize);
      if (zone->blocks == NULL)
        {
          objc_mutex_deallocate(zone->lock);
          objc_free(zone);
          [NSException raise: NSMallocException
                       format: @"No memory to create zone"];
        }
      block = zone->blocks;
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

/* Not in OpenStep. */
void
NSSetDefaultMallocZone (NSZone *zone)
{
  __nszone_private_hidden_default_zone = zone;
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
  /* FIXME: Not thread safe.  But will it matter? */
  if (zone->name != nil)
    [zone->name release];
  if (name == nil)
    zone->name = nil;
  else
    zone->name = [name copy];
}

inline NSString*
NSZoneName (NSZone *zone)
{
  return zone->name;
}

/* Not in OpenStep. */
inline void
NSZoneRegisterRegion (NSZone *zone, void *low, void *high)
{
  return; // Do nothing in this implementation.
}

/* Not in OpenStep. */
inline void
NSDeregisterZone (NSZone *zone)
{
  return; // Do nothing in this implementation
}

/* Not in OpenStep. */
void*
NSZoneRegisterChunk (NSZone *zone, void *chunk)
{
  NSZone **zoneptr = chunk;

  *zoneptr = zone;
  return zoneptr+1;
}

/* Not in OpenStep. */
size_t
NSZoneChunkOverhead (void)
{
  return ZPTRSZ;
}

/* Not in OpenStep. */
inline BOOL
NSZoneCheck (NSZone *zone)
{
  return (zone->check)(zone);
}

/* Not in OpenStep. */
inline struct NSZoneStats
NSZoneStats (NSZone *zone)
{
  return (zone->stats)(zone);
}

/* Zone memory management.
   Copyright (C) 1995, 1996  Free Software Foundation, Inc.
 
   Author: Mark Lakata <lakata@sseos.lbl.gov>
   Date: January 1995
 
   This file is part of the GNU Objective C Class Library.

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

   Description:
 
   These functions manage memory in a way similar to the c library
   functions: malloc() and free().  Instead of allocating small chunks
   of memory with each malloc() call, with this method one must first
   allocate a larger "zone", and then suballocate this in smaller
   chunks.  Many zones can be created, and within each zone, objects
   will be "closer" in virtual memory space thus reducing the need for
   page-swapping.  By intelligently allocating frequently used objects
   from the same zone, you can significantly improve performance on
   systems with paged virtual memory.

   Usage:

   First create a zone with NSCreateZone().  Then allocate memory with
   NSZoneMalloc().  Finally free memory with NSZoneFree(), and free a
   zone with NSDestroyZone().

   A Zone is initialized with a certain memory size, but will
   automagically grow if needed.  The incremental size of enlargement
   is set by the granularity flag.  A good choice for the initial
   memory size and the granularity is vm_page_size.

   Once of the options to NSCreateZone is the _canFree_ flag.  If this
   is YES, then you can use the NSZoneFree() function to reclaim
   memory.  If this is NO, then you cannot use NSZoneFree.  The only
   way then to free the memory is to destroy the entire zone.  This
   option allocates memory much quicker since it requires much less
   bookkeeping.

   NSZoneMalloc(), NSZoneCalloc() and NSZoneRealloc() each return a
   pointer to "size" bytes from zone "zonep".  The different flavors
   work the same as the malloc(), calloc() and realloc() c-library
   routines.

   NSCreateChildZone() and NSMergeZone() are not implemented.

   NSDefaultMemoryZone returns a NULL zone, which means the standard
   malloc zone.  NSZoneFree() frees memory within a
   zone. NSDestroyZone() deallocates the entire zone, including all
   allocated memory within it.  NSZoneFromPtr() finds a zone, given a
   pointer to memory.  The pointer must be one that was returned from
   NSZoneMalloc, or it can be zonep->base.  BXZonePtrInfo() returns
   debugging information for the ptr within a zone.  NSMallocCheck()
   returns 0 if the internal memory allocation is not corrupt, a
   positive integer otherwise. NSNameZone() assigns a name to a zone
   (less than 20 characters.).
  
   */

#include <gnustep/base/preface.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifndef __NeXT__
# include <malloc.h>
#endif
#include <Foundation/NSZone.h>
#include <gnustep/base/objc-malloc.h>

#define DEFAULTLISTSIZE 10

#define UNUSED    0
#define ALLOCATED 1
#define ZONELINK  2

#define WORDSIZE (sizeof(double))

typedef struct _chunkdesc 
{
    void *base;
    int  size;
    int  type;
} chunkdesc;



/* global variable */
llist ZoneList={0,0,sizeof(NSZone *),NULL};
char *memtype[]={"Unused","Allocated","Zone Link"};
char *freeStyle[]={"NO","Yes"};

/* local forward declarations. these are internal routines */
void *addtolist(void *ptr,llist *list,int at);
void delfromlist( llist *list, int at );
int searchheap(llist *heap,void *ptr);

/* things missing from malloc.h, so that gcc doesn't complain. */
/* Deal with bcopy: */
#if STDC_HEADERS || HAVE_STRING_H
#include <string.h>
/* An ANSI string.h and pre-ANSI memory.h might conflict.  */
#if !STDC_HEADERS && HAVE_MEMORY_H
#include <memory.h>
#endif /* not STDC_HEADERS and HAVE_MEMORY_H */
#define index strchr
#define rindex strrchr
#define bcopy(s, d, n) memcpy ((d), (s), (n))
#define bcmp(s1, s2, n) memcmp ((s1), (s2), (n))
#define bzero(s, n) memset ((s), 0, (n))
#else /* not STDC_HEADERS and not HAVE_STRING_H */
#include <strings.h>
/* memory.h and strings.h conflict on some systems.  */
#endif /* not STDC_HEADERS and not HAVE_STRING_H */

#ifdef HAVE_VALLOC
#include <stdlib.h>
#else
#define valloc 	malloc
#endif

/*
 * Returns the default zone used by the malloc(3) calls.
 */
NSZone *NSDefaultMallocZone(void)
{
#ifdef DEBUG
    printf("entered NSDefaultMallocZone\n");
#endif
    return NS_NOZONE;
}


/* 
 * Create a new zone with its own memory pool.
 * If canfree is 0 the allocator will never free memory and mallocing
 * will be fast.
 */
NSZone *NSCreateZone(size_t startSize, size_t granularity, int canFree)
{
    NSZone *ptr;
    chunkdesc temp;
    static int unique=0;
    
#ifdef DEBUG
    printf("entered NSCreateZone\n");
#endif
    ptr = (NSZone *) (*objc_malloc)(sizeof(NSZone));
    if (ptr == NULL) {
#ifdef DEBUG
        printf("out of memory for zone structure\n");
#endif
        return NS_NOZONE;
        }
    ptr->base        = (void *) (*objc_valloc)(startSize);
    if (ptr->base == NULL) {
#ifdef DEBUG
        printf("out of memory for zone\n");
#endif
        return NS_NOZONE;
        }
    
    ptr->size        = startSize;
    ptr->granularity = granularity;
    ptr->canFree     = canFree;
    ptr->parent      = NS_NOZONE;
    sprintf(ptr->name,"zone%d",unique++);
    ptr->heap.Count  = 0;
    ptr->heap.Size   = 0;
    ptr->heap.ElementSize = sizeof(chunkdesc);
    ptr->heap.LList   = NULL;

    temp.base   = ptr->base;
    temp.size   = startSize;
    temp.type   = UNUSED;
    addtolist(&temp,&(ptr->heap),0);

/* this might look funny, but I really want to pass the reference to the
   pointer ptr, and not the ptr it self, because of the way
   addtolist works. */
    addtolist(&ptr,&ZoneList,ZoneList.Count);
#ifdef DEBUG
    printf("zone '%s' created, ptr= %lx\n",ptr->name,(long)ptr);
#endif
   return ptr;
}

/*
 * Create a new zone who obtains memory from another zone.
 * Returns NS_NOZONE if the passed zone is already a child.
 */
NSZone  *NSCreateChildZone(NSZone *parentZone, size_t startSize,
                           size_t granularity, int canFree)
{
    NSZone *child;
/* Unfinished.  This will appear to do what it should do, but it won't.
 * Zone's give a nice improvement over malloc, but my gut feeling is
 * that child zones won't really improve much beyond that.  So I am
 * not implementing them.
 * These routines should 100% call-compatible with the
 * NeXTStep spec.  You can use NSMergeZone() like usual.
 */    

    child = NSCreateZone(startSize,granularity,canFree);
    child->parent = parentZone;

    return child;
}


/*
 * The zone is destroyed and all memory reclaimed.
 */
void NSDestroyZone(NSZone *zonep)
{
    int i,ok;
    chunkdesc *lastchunk;
    
#ifdef DEBUG
    printf("entered NSDestroyZone\n");
#endif

    ok = 0;
    for (i=0;i<ZoneList.Count;i++) {
#ifdef DEBUG
        printf("zone p = %lx list[%d]=%lx name='%s'\n",
               zonep,i,((NSZone **)ZoneList.LList)[i],
               ((NSZone **)ZoneList.LList)[i]->name);
#endif
        if (zonep == ((NSZone **)ZoneList.LList)[i]) {
            ok=1;
            break;
        }
    }
    
    if (ok) {
        lastchunk = &((chunkdesc *)zonep->heap.LList)[zonep->heap.Count-1];
        
        if (lastchunk->type ==  ZONELINK)
            NSDestroyZone((NSZone*)(lastchunk->base));
        free(zonep->base);
        free(zonep->heap.LList);
        delfromlist(&ZoneList,i);
        free(zonep);
    }
    else {
#ifdef DEBUG        
        printf("*** Zone not previously allocated\n");
#endif
    }
    return;
    
}

/*
 * Will merge zone with the parent zone. Malloced areas are still valid.
 * Must be an child zone.
 */
void NSMergeZone(NSZone *zonep)
{
    /* unfinished. */
    /* simply appends the child to the end of the list of zones from
       the parent. Only useful for compatibility. */
    NSZone *current;
    chunkdesc *chunk,new;
    int count;

    if (zonep->parent == NS_NOZONE) return;

    for(current = zonep->parent;
        count = current->heap.Count,
            chunk = &((chunkdesc *)current->heap.LList)[count-1],
            chunk->type == ZONELINK;
        current = chunk->base);

    new.base = zonep;
    new.size = 0;
    new.type = ZONELINK;
    addtolist(&new,&(current->heap),0);
    
    return;
}

void *NSZoneMalloc(NSZone *zonep, size_t size)
{
    int i,pages;
    size_t newsize,oddsize;
    void *ptr;
    chunkdesc temp,*chunk;
    NSZone *newzone;

    if (zonep == NS_NOZONE) return (*objc_malloc) (size);
/* round size up to the nearest word, so that all chunks are word aligned */
    oddsize = (size % WORDSIZE);
    newsize = size - oddsize + (oddsize?WORDSIZE:0);
/* if the chunks in this zone can be freed, then we have to scan the whole
   zone for chunks that have been deallocated for recycling. This requires
   extra time, so it is not as fast as !canFree */
    if (zonep->canFree) {
        for (i=0;i<zonep->heap.Count;i++) {
            chunk = &(((chunkdesc *)zonep->heap.LList)[i]);
            
            if (chunk->type == UNUSED) {
                if (newsize <= chunk->size) {
                    ptr = chunk->base;
                    chunk->type = ALLOCATED;
                    if (newsize < chunk->size) {
                        temp.base = chunk->base+newsize;
                        temp.size = chunk->size-newsize;
                        temp.type = UNUSED;
                        addtolist(&temp,&zonep->heap,i+1);
                        chunk->size = newsize;
                    }
                    return ptr;
                }
            }
            if (chunk->type == ZONELINK) {
#ifdef DEBUG
                printf("following link ...\n");
#endif
                return (NSZoneMalloc((NSZone *)(chunk->base),newsize));
            }
            
        }
    
    }
    else {
        chunk = &(((chunkdesc *)zonep->heap.LList)[0]);
        if (chunk->size > newsize) {
            ptr = chunk->base;
            chunk->size -=newsize;
            return ptr;
        }
        if (zonep->heap.Count == 2) {
            chunk = &(((chunkdesc *)zonep->heap.LList)[1]);
            if (chunk->type == ZONELINK) {
#ifdef DEBUG
                printf("following link ...\n");
#endif
                return (NSZoneMalloc((NSZone *)(chunk->base),newsize));
            }
        }
    }
    
#ifdef DEBUG        
    printf("*** no more memory in zone, creating link to new zone\n");
#endif                
    pages = newsize/(zonep->granularity)+1;
    newzone = NSCreateZone(pages*(zonep->granularity),
                           zonep->granularity,zonep->canFree);
    if (newzone == NS_NOZONE) {
#ifdef DEBUG
        printf("no memory left on system\n");
#endif
        return NULL;
    }
    
    temp.base = (void *)newzone;
    temp.size = 0;
    temp.type = ZONELINK;
    addtolist(&temp,&zonep->heap,zonep->heap.Count);
    return  (NSZoneMalloc(newzone,newsize));
    
}


void *NSZoneCalloc(NSZone *zonep, size_t numElems, size_t byteSize)
{
    void *ptr;

    ptr = NSZoneMalloc(zonep,numElems * byteSize);
    if (ptr) bzero(ptr,numElems*byteSize);
    return ptr;
    
}

void *NSZoneRealloc(NSZone *zonep, void *ptr, size_t size)
{
    int i,diff;
    void *ptr2;
    chunkdesc temp,*chunk,*nextchunk,*priorchunk;
    
    if (zonep == NS_NOZONE) return (*objc_realloc)(ptr,size);
    
    if (zonep->canFree) {
        i = searchheap(&(zonep->heap),ptr);
        
        if (i<0) return NULL;
        
        chunk = &((chunkdesc *)zonep->heap.LList)[i];
        if (chunk->type == ALLOCATED) {
            
            if (ptr == chunk->base) {
/* case 1: same size */
                if (size == chunk->size) {
                    chunk->type = ALLOCATED;
                    return ptr;
                }
                
/* case 2: smaller size */                
                if (size < chunk->size) {
                    temp.base = chunk->base+size;
                    temp.size = chunk->size-size;
                    temp.type = ALLOCATED;          /* the trick here is to
                                                       ALLOCATE this leftover,
                                                       and Free it, so that
                                                       the garbage collection
                                                       is done.*/
                    chunk->size = size;
                    addtolist(&temp,&zonep->heap,i+1);
                    NSZoneFree(zonep,temp.base);
                    return ptr;
                    
                }
/* case 3: larger size */                
/* case 3a: larger size, but there is enough free memory immediately after */
                if (i+1<zonep->heap.Count) {
                    nextchunk = &((chunkdesc *)zonep->heap.LList)[i+1];
                    if (nextchunk->type == UNUSED) 
                        if (size <= chunk->size + nextchunk->size) {
                            diff = size - chunk->size;
                            chunk->size = size;
                            if (diff != nextchunk->size) {
                                nextchunk->base += diff;
                                nextchunk->size -= diff;
                            }
                            else {
                                delfromlist(&zonep->heap,i+1);
                            }
                            
                            return ptr;
                        }
                }
                
/* case 3b: larger size, but there is enough free memory immediately before */
                if (i-1>=0) {
                    priorchunk = &((chunkdesc *)zonep->heap.LList)[i-1];
                    if (priorchunk->type == UNUSED) 
                        if (size < chunk->size + priorchunk->size) {
                            ptr = priorchunk->base;
                            diff = size - priorchunk->size;
                            if (diff != chunk->size) {
                                chunk->base += diff;
                                chunk->size -= diff;
                                chunk->type = UNUSED;
                            }
                            else {
                                delfromlist(&zonep->heap,i-1);
                            }
                            priorchunk->size = size;
                            priorchunk->type = ALLOCATED;
                            bcopy(chunk->base,ptr,chunk->size);
                            return ptr;
                        }
                }
                
                
/* case 3c: larger size, but there is enough free memory immediately
   before+after */
                if (i+1<zonep->heap.Count && i-1>=0) {
                    nextchunk = &((chunkdesc *)zonep->heap.LList)[i+1];
                    priorchunk = &((chunkdesc *)zonep->heap.LList)[i-1];
                    if (nextchunk->type == UNUSED &&
                        priorchunk->type == UNUSED) 
                        if (size <=
                            chunk->size+nextchunk->size+priorchunk->size) {
                            priorchunk->type = ALLOCATED;
                            ptr = priorchunk->base;
                            diff = size - chunk->size - priorchunk->size;
                            if (diff != nextchunk->size) {
                                
                                chunk->base += diff;
                                chunk->size -= diff;
                                chunk->type  = UNUSED;
                                delfromlist(&zonep->heap,i+1);
                            }
                            else {
                                delfromlist(&zonep->heap,i+1);
                                delfromlist(&zonep->heap,i);
                            }
                            
                            priorchunk->size = size;
                            bcopy(chunk->base,ptr,chunk->size);
                            
                            return ptr;
                        }
                }
                
/* case 3d: larger size, have to relocate far away */
                ptr2 = ptr;
                ptr = NSZoneMalloc(zonep,size);
                bcopy(ptr2,ptr,size);
                NSZoneFree(zonep,ptr2);
                return ptr;
            }
        }
#ifdef DEBUG
        printf("*** original malloc info not found\n");
#endif    
        return NULL;
    }
    else {
#ifdef DEBUG
        printf("*** can't use NSZoneRealloc with !canFree\n");
#endif
        return NULL;
    }
    
}

void NSZoneFree(NSZone *zonep, void *ptr)
{
    int i;
    chunkdesc *chunk,*otherchunk;

    
    if (zonep == NS_NOZONE) {
        free(ptr);
        return;
    }
    
    if (zonep->canFree) {
        i = searchheap(&(zonep->heap),ptr);
        if (i<0) {
#ifdef DEBUG
            printf("*** block not found for NSZoneFree\n");
            
#endif
            if ((zonep = NSZoneFromPtr(ptr)) == NS_NOZONE) {
                return;
            }
            i = searchheap(&(zonep->heap),ptr);
            return;
        }
        
    
        chunk = &((chunkdesc *)zonep->heap.LList)[i];
        if (chunk->type == ALLOCATED) {
            chunk->type = UNUSED;
/* combine with upper free block */
            if (i+1<zonep->heap.Count) {
                otherchunk = &((chunkdesc *)zonep->heap.LList)[i+1];
                if (otherchunk->type == UNUSED) {
                    chunk->size += otherchunk->size;
                    delfromlist(&zonep->heap,i+1);
                }
            }
            
/* combine with lower free block */
            if (i-1>=0) {
                otherchunk = &((chunkdesc *)zonep->heap.LList)[i-1];
                if (otherchunk->type == UNUSED) {
                    otherchunk->size += chunk->size;
                    delfromlist(&zonep->heap,i);
                }
            }
            
        }
        else
#ifdef DEBUG
            printf("*** original malloc info not found\n");
#endif
        return;
    }
    
    else {
#ifdef DEBUG
        printf("*** can't use NSZoneFree with !canFree\n");
#endif
        return;
    }
}

/*
 * Returns the zone for a pointer.
 * NS_NOZONE if not in any zone.
 * The ptr must have been returned from a malloc or realloc call.
 */
NSZone *NSZoneFromPtr(void *ptr)
{
    int i;
    
    for (i=0;i<ZoneList.Count;i++) {
        if (searchheap(&(((NSZone **)ZoneList.LList)[i]->heap),ptr) != -1)
            return (NSZone *) ((NSZone **)ZoneList.LList)[i];
    }
    return NS_NOZONE;
}

/*
 * Debugging Helpers.
 */
 
 /*  
  * Will print to stdout information about the pointer, and all the others
  * in the same zone.
  */
void NSZonePtrInfo(void *ptr)
{
    NSZone *tmp,*z;
    chunkdesc *chunk;
    int i;
    
    if (ZoneList.Count == 0) {
        printf("NSZONE: No zones in memory.\n");
        return;
    }
    
    tmp = NSZoneFromPtr(ptr);
    printf("NSZONE: pointer = %lx, zone and chunk marked with * below\n",
           (long) ptr);
    printf(
        "NSZONE: ZONE  [ #] _Pointer __Parent ____Base ____Size Granular free? Name\n");
    
    for (i=0;i<ZoneList.Count;i++) {
        z = ((NSZone **)ZoneList.LList)[i];
        printf("NSZONE: ZONE %c[%2d] %8lx %8lx %8lx %8lx %8lx %-5s '%s'\n",
               (tmp==z)?'*':' ',
               i,
               (long)z,
               (long)z->parent,
               (long)z->base,
               (long)z->size,
               (long)z->granularity,
               freeStyle[z->canFree],
               z->name);
    }
    
    if (tmp != NS_NOZONE) {
        printf("NSZONE: CHUNK - [ #] ____Base ____Size Type (Zone=%lx)\n",
               (long)tmp);
        for (i=0;i<tmp->heap.Count;i++) {
            
            chunk = &((chunkdesc *)tmp->heap.LList)[i];
            printf("NSZONE: CHUNK %c [%2d] %8lx %8lx %s\n",
                   (ptr==chunk->base)?'*':' ',
                   i,
                   (long)chunk->base,
                   (long)chunk->size,
                   memtype[chunk->type]);
        }
        
    }
    
    return;
}

/*
 * Will verify all internal malloc information.
 * This is what malloc_debug calls.
 */
int NSMallocCheck(void)
{
    NSZone *tmp;
    void *base,*currentbase,*zbase;
    int i,j,k,lasttype,type,ok;
    size_t size,zsize;
    
    
/*    if (ZoneList == NULL) return 10; */

    for (i=0;i<ZoneList.Count;i++) {
        tmp = (((NSZone **)ZoneList.LList)[i]);
    
        if (tmp == NS_NOZONE) {
#ifdef DEBUG
            printf("error 1: null zone in ZoneList\n");
#endif            
            return 1;
        }
        
        if (tmp->heap.Count < 1) {
            
#ifdef DEBUG
            printf("error 2: Heap contains %d blocks\n",tmp->heap.Count);
#endif        
            return 2;
        }

        if (tmp->parent != NS_NOZONE) {
            ok = 0;
            for (k=0;k<ZoneList.Count;k++)
                if (tmp->parent == &((NSZone *)ZoneList.LList)[k])
                    ok = 1;
            if (ok==0) {
#ifdef DEBUG
            printf("error 3: parent zone=%lx doesn't exist\n",tmp->parent);
#endif        
                return 3;
            }
        }
        
        zbase = tmp->base;
        zsize = tmp->size;
        currentbase = ((chunkdesc *)tmp->heap.LList)[0].base;
        lasttype = ALLOCATED;
        for (j=0;j<tmp->heap.Count;j++) {
            base = ((chunkdesc *)tmp->heap.LList)[j].base;
            size = ((chunkdesc *)tmp->heap.LList)[j].size;
            type = ((chunkdesc *)tmp->heap.LList)[j].type;

            if (base<zbase || base>=zbase+zsize ||
                size>zsize || base+size>=zbase+zsize) {
#ifdef DEBUG
                printf("error 7: funny chunk addresses:base=%lx size=%lx\n",
                       (long)base,(long)size);
#endif
                return 7;
            }
            
            if (type == ZONELINK) {
                ok = 0;
                for (k=0;k<ZoneList.Count;k++)
                    if (base == ((NSZone *)ZoneList.LList)[k].base)
                        ok = 1;
                if (ok==0) {
#ifdef DEBUG
            printf("error 4: zone to link=%lx doesn't exist\n",base);
#endif        
                    return 4;
                }
                continue;
            }
            
            if (base != currentbase) {
#ifdef DEBUG
                printf("error 5: blocks are not contiguous.\n");
#endif                
                return 5;
            }
            if (lasttype == UNUSED && type == UNUSED) {
#ifdef DEBUG
                printf("error 6: two consecutive UNUSED blocks\n");
                return 6;
#endif
            }
            lasttype = type;
            currentbase += ((chunkdesc *)tmp->heap.LList)[j].size;
        }
        
    }
    return 0;
}

/*
 * Give a zone a name.
 *
 * The string will be copied.
 */
    void NSNameZone(NSZone *zonep, const char *name)
{
#ifdef DEBUG
    printf("current name=%s changing to %s\n",zonep->name,name);
#endif
    if (zonep != NULL) {
        strncpy(zonep->name,name,MAXZONENAMELENGTH);
        zonep->name[MAXZONENAMELENGTH]=0;
    }
    return;
}

void
NSSetZoneName (NSZone *z, NSString *name)
{
  /* xxx Not implemented. */
  abort ();
}

NSString *NSZoneName (NSZone *z)
{
  /* xxx Not implemented. */
  abort ();
  return NULL;
}


/* these are internal routines, not to be called by the user.
   They manipulate pseudo List objects, but with less overhead.
   */

void *addtolist(void *ptr,llist *list, int at)    
{
    void *newelement;
    
    /* increase allocated size for list if necessary */
    if (list->Count>= list->Size) {
        if (list->LList == NULL) {
            list->Size = DEFAULTLISTSIZE;
            list->LList = (void *)
	      (*objc_malloc)(list->ElementSize * list->Size);
        }
        else {
            list->Size *= 2;
            list->LList = (void *)
	      (*objc_realloc)(list->LList, list->ElementSize * list->Size);
        }
        
    }
    
    newelement = &((char *)list->LList)[at*list->ElementSize];
    
    /* add element to list at position at */
    if (at != list->Count)
        bcopy(&((char *)list->LList)[at*list->ElementSize],
              &((char *)list->LList)[(at+1)*list->ElementSize],
              list->ElementSize*(list->Count - at)
            );
    bcopy(ptr,newelement,list->ElementSize);
    list->Count++;
    return newelement;
    
}


void delfromlist( llist *list, int at )
{
    if (at+1<list->Count)
        bcopy(&((char *)list->LList)[(at+1)*list->ElementSize],
              &((char *)list->LList)[(at  )*list->ElementSize],
              list->ElementSize*(list->Count - at-1));
              
    list->Count--;
}

/* this searches the heap linearly.. someone can change this to
   a binary search if they want. */

int searchheap(llist *heap,void *ptr)
{
    int i;
    
    for (i=0;i<heap->Count;i++)
        if (ptr == ((chunkdesc *)heap->LList)[i].base) return i;

    return -1;
}

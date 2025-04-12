
/* Emulation of ARC runtime support for weak references and associated objects,
 * partially based on the libobjc2 runtime implementation for weak objects.
 */

#import "common.h"
#import "Foundation/Foundation.h"
#import "../GSPrivate.h"
#import "../GSPThread.h"

static Class	persistentClasses[1];
static int	persistentClassCount = sizeof(persistentClasses)/sizeof(Class);

/* This function needs to identify objects which should NOT be handled by
 * weak references.
 * Nil is a special case which can not be stored as a weak reference because
 * it indicates the absence of an object etc.
 * Persistent objects do not need any sort of weak (or strong) reference and
 * if they are immutable then trying to mark them as referenced would crash.
 */
__attribute__((always_inline))
static inline BOOL
isPersistentObject(id obj)
{
  Class	c;
  int	i;

  if (nil == obj)
    {
      return YES;
    }

  /* If the alignment of the object does not match that needed for a
   * pointer (to the class of the object) then the object must be a
   * special one of some sort and we assume it's persistent.
   */
#if	ALIGNOF_OBJC_OBJECT > 1
  if ((intptr_t)obj & (ALIGNOF_OBJC_OBJECT - 1))
    {
      return YES;
    }
#endif

  c = object_getClass(obj);
  if (class_isMetaClass(c))
    {
      return YES;	// obj was a class rather than an instance
    }

  for (i = 0; i < persistentClassCount; i++)
    {
      if (persistentClasses[i] == c)
	{
	  return YES;	// the object is a persistent instance
	}
    }
  return NO;
}

static int  WeakRefClass = 0;

#define GSI_MAP_NODE_CLASS  (&WeakRefClass)
#define GSI_MAP_CLEAR_KEY(M, X) ((*X).obj = nil)       
#define GSI_MAP_HASH(M, X)	((NSUInteger)(X.obj) >> 2)
#define GSI_MAP_EQUAL(M, X, Y)	(X.obj == Y.obj)
#define GSI_MAP_RETAIN_KEY(M, X)        
#define GSI_MAP_RELEASE_KEY(M, X)       
#define GSI_MAP_RETAIN_VAL(M, X)        
#define GSI_MAP_RELEASE_VAL(M, X)       
#define GSI_MAP_KTYPES  GSUNION_OBJ
#define GSI_MAP_VTYPES  GSUNION_NSINT | GSUNION_PTR

#include "GNUstepBase/GSIMap.h"

typedef	GSIMapNode_t	WeakRef;

static gs_mutex_t  	weakLock = GS_MUTEX_INIT_STATIC;

/* The weakRefs table contains weak references (nodes) for weak references
 * to any active objects.
 */
static GSIMapTable_t	weakRefs = { 0 };

/* The deallocated list contains the weak references (nodes) for objects
 * which have already been deallocated (so the references are now to nil).
 */
static WeakRef		*deallocated = NULL;

/* The associated table contains associated object lists for any objects
 * which have associated objects.
 */
static GSIMapTable_t	associated = { 0 };

/* This must be called on startup before any weak references are taken
 * or associated objects are used.
 */
void
GSWeakInit()
{
  GS_MUTEX_LOCK(weakLock);
  if (0 == weakRefs.increment)
    {
      GSIMapInitWithZoneAndCapacity(
	&weakRefs, NSDefaultMallocZone(), 1024);
      GSIMapInitWithZoneAndCapacity(
	&associated, NSDefaultMallocZone(), 1024);
      persistentClasses[0] = [NXConstantString class];
    }
  GS_MUTEX_UNLOCK(weakLock);
}

/* Load from a weak pointer and return whether this really was a weak
 * reference or a strong (not deallocatable) object in a weak pointer.
 * The object will be stored in 'obj' and the weak reference in 'ref',
 * if one exists.
 */
inline static BOOL
loadWeakPointer(id *addr, id *obj, WeakRef **ref)
{
  id	oldObj = *addr;

  if (nil == oldObj)
    {
      *ref = NULL;
      *obj = nil;
      return NO;
    }
  if (*(void**)oldObj == (void*)&WeakRefClass)
    {
      *ref = (WeakRef*)oldObj;
      *obj = (*ref)->key.obj;
      return YES;
    }
  *ref = NULL;
  *obj = oldObj;
  return NO;
}

__attribute__((always_inline))
static inline BOOL
weakRefRelease(WeakRef *ref)
{
  ref->value.nsi--;
  if (ref->value.nsi == 0)
    {
      if (nil == ref->key.obj)
	{
	  /* The object was already deallocated so we must remove this
	   * reference from the deallocated list.
	   */
	  if (deallocated == ref)
	    {
	      deallocated = ref->nextInBucket;
	    }
	  else
	    {
	      WeakRef	*tmp = deallocated;

	      while (tmp->nextInBucket != 0)
		{
		  if (tmp->nextInBucket == ref)
		    {
		      tmp->nextInBucket = ref->nextInBucket;
		      break;
		    }
		  tmp = tmp->nextInBucket;
		}
	    }
	  ref->nextInBucket = weakRefs.freeNodes;
          weakRefs.freeNodes = ref;
	}
      else
	{
	  GSIMapBucket  bucket = GSIMapBucketForKey(&weakRefs, ref->key);

	  GSIMapRemoveNodeFromMap(&weakRefs, bucket, ref);
	  GSIMapFreeNode(&weakRefs, ref);
	}
      return YES;
    }
  return NO;
}

/* We should record the fact that the object has weak references (unless
 * it is a persistent one).
 * Return YES if the object is persistent and should not have weak references,
 * NO otherwise.
 */
static BOOL
setObjectHasWeakRefs(id obj)
{
  BOOL isPersistent = isPersistentObject(obj);

  if (NO == isPersistent)
    {
      GSPrivateMarkedWeak(obj, YES);
    }
  return isPersistent;
}

static WeakRef *
incrementWeakRefCount(id obj)
{       
  GSIMapKey	key;
  GSIMapBucket  bucket;
  WeakRef 	*ref;

  key.obj = obj;
  bucket = GSIMapBucketForKey(&weakRefs, key);
  ref = GSIMapNodeForKeyInBucket(&weakRefs, bucket, key);
  if (NULL == ref)
    {
      ref = GSIMapGetNode(&weakRefs);

      ref->key.obj = obj;
      ref->value.nsi = 1;
      GSIMapAddNodeToBucket(bucket, ref);
      weakRefs.nodeCount++;
      return ref;
    }
  ref->value.nsi++;

  return ref;
}

id
objc_storeWeak(id *addr, id obj)
{
  WeakRef	*oldRef;
  id 		old;
  BOOL 		isGlobalObject;

  GS_MUTEX_LOCK(weakLock);
  loadWeakPointer(addr, &old, &oldRef);
  /* If the old and new values are the same (and we are not setting a nil
   * value to destroy an existing weak reference), then we don't need to
   * do anything.
   */
  if ((obj != nil || oldRef == NULL) && old == obj)
    {
      GS_MUTEX_UNLOCK(weakLock);
      return obj;
    }
  isGlobalObject = setObjectHasWeakRefs(obj);

  /* If we old ref exists, decrement its reference count.  This may also
   * delete the weak reference from the map.
   */
  if (oldRef != NULL)
    {
      weakRefRelease(oldRef);
    }

  /* If we're storing nil, then just write a null pointer.
   */
  if (nil == obj)
    {
      *addr = obj;
    }
  else if (isGlobalObject)
    {
      /* If this is a global object, it's never deallocated,
       * so we don't make this a weak reference.
       */
      *addr = obj;
    }
  else if ([obj retainCount] == 0)
    {
      /* The object is being deallocated ... we must store nil.
       */
      *addr = obj = nil;
    }
  else
    {
      *addr = (id)incrementWeakRefCount(obj);
    }
  GS_MUTEX_UNLOCK(weakLock);
  return obj;
}

/* Function called when objects are deallocated
 */
BOOL
objc_delete_weak_refs(id obj)
{
  GSIMapKey	key;
  GSIMapBucket  bucket;
  WeakRef 	*ref;

  /* For performance we should have marked the object as having
   * weak references and we check that in order to avoid the cost
   * of the map table lookup when it's not needed.
   */
  if (NO == GSPrivateMarkedWeak(obj, NO))
    {
      return NO;
    }

  key.obj = obj;
  GS_MUTEX_LOCK(weakLock);
  bucket = GSIMapBucketForKey(&weakRefs, key);
  ref = GSIMapNodeForKeyInBucket(&weakRefs, bucket, key);
  if (ref)
    {
      GSIMapRemoveNodeFromBucket(bucket, ref);
      ref->key.obj = nil;
      weakRefs.nodeCount--;
      /* The object is deallocated but there are still weak references
       * to it so we put the weak reference node in the deallocated list.
       */
      ref->nextInBucket = deallocated;
      deallocated = ref;
    }
  GS_MUTEX_UNLOCK(weakLock);
  return YES;
}

id
objc_loadWeakRetained(id *addr)
{
  id 		obj;
  WeakRef 	*ref;

  GS_MUTEX_LOCK(weakLock);

  /* If this is not actually a weak pointer, return the object directly.
   */
  if (!loadWeakPointer(addr, &obj, &ref))
    {
      GS_MUTEX_UNLOCK(weakLock);
      return obj;
    }

  if (nil == obj)
    {
      /* The object has been destroed so we should remove the weak
       * reference to it.
       */
      if (ref != NULL)
	{
	  weakRefRelease(ref);
	  *addr = nil;
	}
      GS_MUTEX_UNLOCK(weakLock);
      return nil;
    }

  obj = [obj retain];
  GS_MUTEX_UNLOCK(weakLock);
  return obj;
}

id
objc_loadWeak(id *object)
{
  return [objc_loadWeakRetained(object) autorelease];
}

void
objc_copyWeak(id *dest, id *src)
{
  /* Don't retain or release.
   * 'src' is a valid pointer to a __weak pointer or nil.
   * 'dest' is a valid pointer to uninitialised memory.
   * After this operation, 'dest' should contain whatever 'src' contained.
   */
  id 		obj;
  WeakRef 	*srcRef;

  GS_MUTEX_LOCK(weakLock);
  loadWeakPointer(src, &obj, &srcRef);
  *dest = *src;
  if (srcRef)
    {
      srcRef->value.nsi++;
    }
  GS_MUTEX_UNLOCK(weakLock);
}

void
objc_moveWeak(id *dest, id *src)
{
  /* Don't retain or release.
   * 'dest' is a valid pointer to uninitialized memory.
   * 'src' is a valid pointer to a __weak pointer.
   * This operation moves from *src to *dest and must be atomic with respect
   * to other stores to *src via 'objc_storeWeak'.
   */
  GS_MUTEX_LOCK(weakLock);
  *dest = *src;
  *src = nil;
  GS_MUTEX_UNLOCK(weakLock);
}

void
objc_destroyWeak(id *obj)
{
  WeakRef	*oldRef;
  id 		old;

  GS_MUTEX_LOCK(weakLock);
  loadWeakPointer(obj, &old, &oldRef);
  /* If the old ref exists, decrement its reference count.
   * This may also remove the weak reference from the map.
   */
  if (oldRef != NULL)
    {
      weakRefRelease(oldRef);
    }
  GS_MUTEX_UNLOCK(weakLock);
}

id
objc_initWeak(id *addr, id obj)
{
  BOOL 		isGlobalObject;

  if (nil == obj)
    {
      *addr = nil;
      return nil;
    }

  GS_MUTEX_LOCK(weakLock);
  isGlobalObject = setObjectHasWeakRefs(obj);
  if (isGlobalObject)
    {
      *addr = obj;
      GS_MUTEX_UNLOCK(weakLock);
      return obj;
    }

  if ([obj retainCount] == 0)
    {
      *addr = nil;
      GS_MUTEX_UNLOCK(weakLock);
      return nil;
    }
  if (nil != obj)
    {
      *(WeakRef**)addr = incrementWeakRefCount(obj);
    }
  GS_MUTEX_UNLOCK(weakLock);
  return obj;
}



static gs_mutex_t  	associatedLock = GS_MUTEX_INIT_STATIC;

#define	REFBLOCKSIZE	8

typedef struct association_t {
  id				value;
  const void			*key;
  objc_AssociationPolicy	policy;
} association;

typedef struct assocblock_t {
  gs_mutex_t		mutex;	// Protect this block
  struct assocblock_t	*more;	// pointer to next block if any
  struct association_t	associations[REFBLOCKSIZE];
} *assocptr;

/* Returns a slot matching the key or an empty slot (or NULL if neither
 * exists and mayCreate is NO).
 */
static association *
getAssociation(const void *key, assocptr ptr, BOOL mayCreate)
{
  unsigned	index;

  for (index = 0; index < REFBLOCKSIZE; index++)
    {
      if (ptr->associations[index].key == key)
	{
	  return ptr->associations + index;
	}
    }
  if (ptr->more)
    {
      return getAssociation(key, ptr->more, mayCreate);
    }
  if (mayCreate)
    {
      ptr->more = (assocptr)calloc(1, sizeof(struct assocblock_t));
      ptr->more->associations[0].key = key;
      return ptr->more->associations;
    }
  return NULL;
}

static void
setAssociation(association *a, const void *key, id value,
  objc_AssociationPolicy policy)
{
  objc_AssociationPolicy	oldPolicy;
  id				oldObject;

  switch (policy)
    {
      case OBJC_ASSOCIATION_COPY_NONATOMIC:
      case OBJC_ASSOCIATION_COPY:
	value = [value copy];
	break;
      case OBJC_ASSOCIATION_RETAIN_NONATOMIC:
      case OBJC_ASSOCIATION_RETAIN:
	value = [value retain];
	break;
      default:
	break;
    }

  oldObject = a->value;
  oldPolicy = a->policy;

  a->value = value;
  a->key = key;
  a->policy = policy;

  switch (oldPolicy)
    {
      case OBJC_ASSOCIATION_COPY_NONATOMIC:
      case OBJC_ASSOCIATION_COPY:
      case OBJC_ASSOCIATION_RETAIN_NONATOMIC:
      case OBJC_ASSOCIATION_RETAIN:
	[oldObject release];
	break;
      default:
	break;
    }
}

static void
clearAssociations(assocptr ptr)
{
  if (ptr)
    {
      unsigned	index = REFBLOCKSIZE;

      clearAssociations(ptr->more);
      free(ptr->more);
      ptr->more = NULL;
      for (index = 0; index < REFBLOCKSIZE; index++)
	{
	  setAssociation(ptr->associations + index, NULL, nil, 0);
	}
    }
}

id
objc_getAssociatedObject(id object, const void *key)
{
  GSIMapKey	nodeKey;
  GSIMapBucket  bucket;
  GSIMapNode	node;
  assocptr	block = NULL;
  id		found = nil;

  nodeKey.obj = object;

  /* Look up the associations for the object, ensuring that the lock
   * for those associations is obtained before we release the global
   * lock.
   */
  GS_MUTEX_LOCK(associatedLock);
  bucket = GSIMapBucketForKey(&associated, nodeKey);
  node = GSIMapNodeForKeyInBucket(&associated, bucket, nodeKey);
  if (node)
    {
      block = node->value.ptr;
      GS_MUTEX_LOCK(block->mutex);
    }
  GS_MUTEX_UNLOCK(associatedLock);

  /* If there were any associated objects, search for the one matching
   * the key and return it.
   */
  if (block)
    {
      association	*ptr = getAssociation(key, block, NO);

      if (NULL == ptr)
	{
	  GS_MUTEX_UNLOCK(block->mutex);
	}
      else
	{
	  objc_AssociationPolicy	policy = ptr->policy;

	  found = ptr->value;
	  if (policy & 0x300)
	    {
	      // Atomic ... hold lock until after we have retained the value.
	      switch (policy)
		{
		  case OBJC_ASSOCIATION_COPY:
		  case OBJC_ASSOCIATION_RETAIN:
		    found = [found retain];
		    break;
		  default:
		    ;
		}
	      GS_MUTEX_UNLOCK(block->mutex);
	      switch (policy)
		{
		  case OBJC_ASSOCIATION_COPY:
		  case OBJC_ASSOCIATION_RETAIN:
		    found = [found autorelease];
		    break;
		  default:
		    ;
		}
	    }
	  else
	    {
	      // Non-Atomic ... assume we don't need retain/autorelease
	      GS_MUTEX_UNLOCK(block->mutex);
	    }
	}
    }
  return found;
}

void
objc_removeAssociatedObjects(id object)
{
  GSIMapKey	key;
  GSIMapBucket  bucket;
  GSIMapNode	node;
  assocptr	ptr = NULL;

  GS_MUTEX_LOCK(associatedLock);
  key.obj = object;
  bucket = GSIMapBucketForKey(&associated, key);
  node = GSIMapNodeForKeyInBucket(&associated, bucket, key);
  if (node)
    {
      GSIMapRemoveNodeFromMap(&associated, bucket, node);
      ptr = node->value.ptr;
      node->value.ptr = NULL;
      GSIMapFreeNode(&associated, node);
      GS_MUTEX_LOCK(ptr->mutex);
    }
  GS_MUTEX_UNLOCK(associatedLock);
  if (ptr)
    {
      clearAssociations(ptr);
      GS_MUTEX_UNLOCK(ptr->mutex);
      free(ptr);
    }
}

void
objc_setAssociatedObject(id object, const void *key, id value,
  objc_AssociationPolicy policy)
{
  GSIMapKey	nodeKey;
  GSIMapBucket  bucket;
  GSIMapNode	node;
  assocptr	blk;
  association	*association;

  nodeKey.obj = object;

  /* Look up the associations for the object, ensuring that the lock
   * for those associations is obtained before we release the global
   * lock.
   */
  GS_MUTEX_LOCK(associatedLock);
  bucket = GSIMapBucketForKey(&associated, nodeKey);
  node = GSIMapNodeForKeyInBucket(&associated, bucket, nodeKey);
  if (NULL == node)
    {
      node = GSIMapGetNode(&associated);

      node->key.obj = object;
      node->value.ptr = calloc(1, sizeof(struct assocblock_t));
      GSIMapAddNodeToBucket(bucket, node);
      associated.nodeCount++;
      if (NO == isPersistentObject(object))
	{
	  // Needs cleanup on dealloc
	  GSPrivateMarkedAssociations(object, YES);
	}
    }
  blk = (assocptr)(node->value.ptr);
  GS_MUTEX_LOCK(blk->mutex);
  GS_MUTEX_UNLOCK(associatedLock);
  association = getAssociation(key, blk, YES);
  if (policy & 0x300)
    {
      // Atomic ... hold lock until new value is in place
      setAssociation(association, key, value, policy);
      GS_MUTEX_UNLOCK(blk->mutex);
    }
  else
    {
      // Non-Atomic ... release lock und then set association value
      GS_MUTEX_UNLOCK(blk->mutex);
      setAssociation(association, key, value, policy);
    }
}


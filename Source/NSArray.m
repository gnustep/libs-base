#include <foundation/NSArray.h>

@implementation NSArray

+ (id) allocWithZone: (NSZone*)zone
{
  return [self alloc];		/* for now, until we get zones. */
}

+ (id) array
{
  return [[[self alloc] init] autorelease];
}

+ (id) arrayWithObject: anObject
{
  return [[[[self alloc] init] addObject: anObject] autorelease];
}

+ (id) arrayWithObject: firstObject, ...
{
  va_list ap;
  Array *n = [[self alloc] init];
  id o;

  [n addObject:firstObject];
  va_start(ap, firstObject);
  while ((o = va_arg(ap, id)))
    [n addObject:o];
  va_end(ap);
  return [n autorelease];
}

- (id) initWithArray: (NSArray*)array
{
  int i, c;

  c = [array count];
  [super initWithCapacity:c];
  for (i = 0; i < c; i++)
    [self addObject:[array objectAtIndex:i]];
  return self;
}

- (id) initWithObjects: (id)firstObject, ...
{
  va_list ap;
  id o;

  [super init];
  [self addObject:firstObject];
  va_start(ap, firstObject);
  while ((o = va_arg(ap, id)))
    [self addObject:o];
  va_end(ap);
  return self;
}

- (id) initWithObjects: (id*)objects count: (unsigned int)count
{
  [self initWithCapacity:count];
  while (count--)
    [self addObject:objects[count]];
  return self;
}

- (BOOL) containsObject: (id)candidate
{
  return [self includesObject:candidate];
}

#if 0
- (unsigned) count;		/* inherited */
- (unsigned) indexOfObject: (id)anObject; /* inherited */
#endif

- (unsigned) indexOfObjectIdenticalTo: (id)anObject
{
  int i;
  for (i = 0; i < _count; i++)
    if (anObject == _contents_array[i])
      return i;
  return UINT_MAX;
}

#if 0
- (id) lastObject;		/* inherited */
- (id) objectAtIndex: (unsigned)index;
#endif

- (NSEnumerator*) objectEnumerator
{
  [self notImplemented:_cmd];
  return nil;
}

- (NSEnumerator*) reverseObjectEnumerator
{
  [self notImplemented:_cmd];
  return nil;
}

#if 0
- (void) makeObjectsPerform: (SEL)aSelector;
- (void) makeObjectsPerform: (SEL)aSelector withObject: (id)anObject;
#endif

- (id) firstObjectCommonWithArray: (NSArray*)otherArray
{
  BOOL is_in_otherArray (id o)
    {
      return [otherArray containsObject:o];
    }
  id none_found(arglist_t)
    {
      return nil;
    }
  return [self detectObjectByCalling:is_in_otherArray
	       ifNoneCall:none_found];
}

- (BOOL) isEqualToArray: (NSArray*)otherArray
{
  int i;

  if (_count != [otherArray count])
    return NO;
  for (i = 0; i < _count; i++)
    if ([_contents_array[i] isEqual:[otherArray objectAtIndex:i]])
      return NO;
  return YES;
}

- (NSArray*) sortedArrayUsingFunction: (int(*)(id,id,void*))comparator
   context: (void*)context
{
  id n = [self copy];
  int compare(id o1, id o2)
    {
      return comparator(o1, o2, context);
    }
  [n sortObjectsByCalling:compare];
  return [n autorelease];
}

- (NSArray*) sortedArrayUsingSelector: (SEL)comparator
{
  id n = [self copy];
  int compare(id o1, id o2)
    {
      return [o1 perform:comparator with:o2];
    }
  [n sortObjectsByCalling:compare];
  return [n autorelease];
}

- (NSArray*) subarrayWithRange: (NSRange)range
{
  id n = [self emptyCopy];
  [self notImplemented:_cmd];
  return [n autorelease];
}

- (NSString*) componentsJoinedByString: (NSString*)separator
{
  
}

@end


static unsigned released_capacity = 0;
static unsigned released_index = 0;
static id *released_objects = NULL;
static void **released_stack_pointers = NULL;

#define DEFAULT_SIZE 64

static void *s1, *s2;
static void unsigned stack_release_offset;
static void init_stack_release()
{
  s1 = get_stack();
  [Object _stackReleaseTest];
  stack_release_offset = s2 - s1;
  released_capacity = DEFAULT_SIZE;
  OBJC_MALLOC(released_objects, id, released_capacity);
  OBJC_MALLOC(released_stack_pointers, void*, released_capacity);
}

static void*
get_stack()
{
  int i;
  return &i;
}

static inline void
grow_released_arrays()
{
  if (index == released_capacity)
    {
      released_capacity *= 2;
      OBJC_REALLOC(released_objects, id, released_capacity);
      OBJC_REALLOC(released_stack_pointers, void*, released_capacity);
    }
}

@implementation Object (Releasing)

+ _stackReleaseTest
{
  s2 = get_stack();
}

- stackRelease
/* - releaseLater */
{
  static init_done = 0;

  /* Initialize if we haven't done it yet */
  if (!init_done)
    {
      init_stack_release();
      init_done = 1;
    }
  
  /* Do the pending releases of other objects */
  /* xxx This assumes stack grows up */
  while ((released_stack_pointers[released_index] 
	  > (get_stack() - stack_release_offset))
	 && released_index)
    {
      [released_objects[released_index] release];
      released_index--;
    }
  
  /* Queue this object for later release */
  released_index++;
  grow_released_arrays();
  released_objects[released_index] = self;

  return self;
}

@end

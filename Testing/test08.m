
#include <objects/objects.h>

void test(id objects)
{
  TypedStream *stream;

  [objects addElementsCount:6, ((elt)0),((elt)1),((elt)5),((elt)3),
	 ((elt)4),((elt)2)];
  printf("written ");
  [objects printForDebugger];

  stream = objc_open_typed_stream_for_file("test08.data", OBJC_WRITEONLY);
  objc_write_root_object(stream, objects);
  objc_close_typed_stream(stream);
  [objects release];

  stream = objc_open_typed_stream_for_file("test08.data", OBJC_READONLY);
  objc_read_object(stream, &objects);
  printf("read    ");
  [objects printForDebugger];
  [objects release];
}

int main()
{
  id objects;

  objects = [[Array alloc] initWithType:@encode(int)];
  test(objects);

  objects = [[Bag alloc] initWithType:@encode(int)];
  test(objects);

  objects = [[Set alloc] initWithType:@encode(int)];
  test(objects);

  objects = [[GapArray alloc] initWithType:@encode(int)];
  test(objects);

  objects = [[EltNodeCollector alloc] initWithType:@encode(int)
	  nodeCollector:[[LinkedList alloc] init]
	  nodeClass:[LinkedListEltNode class]];
  test(objects);

  objects = [[EltNodeCollector alloc] initWithType:@encode(int)
	  nodeCollector:[[BinaryTree alloc] init]
	  nodeClass:[BinaryTreeEltNode class]];
  test(objects);

/*
  objects = [[EltNodeCollector alloc] initWithType:@encode(int)
	  nodeClass:[RBTreeEltNode class]];
  test(objects);
*/

  exit(0);
}



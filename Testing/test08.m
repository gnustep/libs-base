
#include <gnustep/base/all.h>
#include <gnustep/base/BinaryCoder.h>

void test(id objects)
{
  Coder *coder;
  id read_objects;

  [objects addElementsCount:6, ((elt)0),((elt)1),((elt)5),((elt)3),
	 ((elt)4),((elt)2)];
  printf("written ");
  [objects printForDebugger];

  coder = [[BinaryCoder alloc] 
	   initEncodingOnStream: [[StdioStream alloc] 
				  initWithFilename:"test08.data"
				  fmode: "w"]];
  [coder encodeObject:objects
	 withName:""];
  [coder release];
  [objects release];

  coder = [[BinaryCoder alloc] 
	   initDecodingOnStream: [[StdioStream alloc] 
				  initWithFilename:"test08.data"
				  fmode: "r"]];
  [coder decodeObjectAt:&read_objects withName:NULL];
  [coder release];
  printf("read    ");
  [read_objects printForDebugger];
  [read_objects release];
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

#if 0
  objects = [[GapArray alloc] initWithType:@encode(int)];
  test(objects);
#endif

  objects = [[EltNodeCollector alloc] initWithType:@encode(int)
	  nodeCollector:[[LinkedList alloc] init]
	  nodeClass:[LinkedListEltNode class]];
  test(objects);

#if 0
  objects = [[EltNodeCollector alloc] initWithType:@encode(int)
	  nodeCollector:[[BinaryTree alloc] init]
	  nodeClass:[BinaryTreeEltNode class]];
  test(objects);
#endif

#if 0
  objects = [[EltNodeCollector alloc] initWithType:@encode(int)
	  nodeClass:[RBTreeEltNode class]];
  test(objects);
#endif

  exit(0);
}



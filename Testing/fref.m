/* Test NSArchiver on encoding of self-referential forward references. */

#include <Foundation/NSArchiver.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>

/* This object encodes an -encodeConditionalObject: reference to a Foo. */
@interface SubFoo : NSObject
{
  id super_foo;
  int label;
}
@end

/* This object encodes an -encodeObject: reference to a SubFoo. */
@interface Foo : NSObject
{
  id sub_foo;
  int label;
}
- (int) label;
@end

@implementation SubFoo

- (void) dealloc
{
  RELEASE(super_foo);
  [super dealloc];
}

- (id) initWithSuperFoo: (id)o label: (int)l
{
  self = [super init];
  super_foo = RETAIN(o);
  label = l;
  return self;
}

- (id) superFoo
{
  return super_foo;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
  printf ("In [SubFoo encodeWithCoder:]\n");
  [coder encodeConditionalObject: super_foo];
  [coder encodeValueOfObjCType: @encode(int)
	 at: &label];
}

- (id) initWithCoder: (NSCoder*)coder
{
  [coder decodeValueOfObjCType: @encode(id)
			    at: &super_foo];
  [coder decodeValueOfObjCType: @encode(int)
			    at: &label];
  return self;
}

- (void) print
{
  printf ("label = %d, super label = %d\n",
	  label, [super_foo label]);
}

@end

@implementation Foo 

- (void) dealloc
{
  RELEASE(sub_foo);
  [super dealloc];
}

- (id) init
{
  self = [super init];
  sub_foo = nil;
  label = 0;
  return self;
}

- (void) setSubFoo: o
{
  ASSIGN(sub_foo, o);
}

- (id) subFoo
{
  return sub_foo;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
  printf ("In [Foo encodeWithCoder:]\n");
  [coder encodeObject: sub_foo];
  [coder encodeValueOfObjCType: @encode(int)
	 at: &label];
}

- (id) initWithCoder: (NSCoder*)coder
{
  [coder decodeValueOfObjCType: @encode(id)
			    at: &sub_foo];
  [coder decodeValueOfObjCType: @encode(int)
			    at: &label];
  return self;
}

- (int) label
{
  return label;
}

- (void) setLabel: (int)l
{
  label = l;
}

@end

/* Test the use of -encodeConditional to encode a forward reference 
   to an object. */
void
test_fref ()
{
  id array;
  id foo, sub_foo;
  printf ("\nTest encoding of forward references\n");

  array = [[NSMutableArray alloc] init];
  foo = [[Foo alloc] init];
  [foo setLabel: 4];
  sub_foo = [[SubFoo alloc] initWithSuperFoo: foo label: 3];
  [foo setSubFoo: sub_foo];
  [array addObject: foo];
  [array insertObject: sub_foo atIndex: 0];

  [NSArchiver archiveRootObject: array toFile: @"fref.dat"];
  printf ("Encoded:  ");
  [sub_foo print];
  RELEASE(foo);
  RELEASE(sub_foo);
  RELEASE(array);

  array = [NSUnarchiver unarchiveObjectWithFile: @"fref.dat"];
  foo = [array objectAtIndex: 1];
  sub_foo = [foo subFoo];
  printf ("Decoded:  ");
  [sub_foo print];
}

/* Test the encode of a self-referential forward reference. */
void
test_self_fref ()
{
  id foo, sub_foo;
  printf ("\nTest encoding of self-referential forward references\n");

  foo = [[Foo alloc] init];
  [foo setLabel: 4];
  sub_foo = [[SubFoo alloc] initWithSuperFoo: foo label: 3];
  [foo setSubFoo: sub_foo];

  [NSArchiver archiveRootObject: foo toFile: @"fref.dat"];
  printf ("Encoded:  ");
  [sub_foo print];
  RELEASE(foo);
  RELEASE(sub_foo);

  foo = [NSUnarchiver unarchiveObjectWithFile: @"fref.dat"];
  sub_foo = [foo subFoo];
  printf ("Decoded:  ");
  [sub_foo print];
}

int
main ()
{
  CREATE_AUTORELEASE_POOL(arp);

  test_fref ();
  test_self_fref ();

  RELEASE(arp);

  exit (0);
}

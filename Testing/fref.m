/* Test NSArchiver on encoding of self-referential forward references. */

#include <Foundation/NSArchiver.h>
#include <Foundation/NSArray.h>

/* Use GNU Archiving features, if they are available. */
#define TRY_GNU_ARCHIVING 1

/* The -initWithCoder methods substitutes another object for self. */
static int decode_substitutes;

#define GNU_ARCHIVING (TRY_GNU_ARCHIVING && defined(OBJECTS_MAJOR_VERSION))

#if GNU_ARCHIVING
#include <gnustep/base/Archiver.h>
/* Use text coding instead of binary coding */
#define TEXTCSTREAM 0
#if TEXTCSTREAM
#include <gnustep/base/Archiver.h>
#include <gnustep/base/TextCStream.h>
#endif
#endif /* GNU_ARCHIVING */

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

- initWithSuperFoo: o label: (int)l
{
  [super init];
  super_foo = o;
  label = l;
  return self;
}

- superFoo
{
  return super_foo;
}

- (void) encodeWithCoder: coder
{
  printf ("In [SubFoo encodeWithCoder:]\n");
  [super encodeWithCoder: coder];
#if GNU_ARCHIVING
  [coder encodeObjectReference: super_foo
	 withName: @"super foo"];
#else
  [coder encodeConditionalObject: super_foo];
#endif
  [coder encodeValueOfObjCType: @encode(int)
	 at: &label];
}

- initWithCoder: coder
{
  if (decode_substitutes)
    {
      id o = self;
      self = [[[self class] alloc] init];
      [o release];
    }
  else
    {
      self = [super initWithCoder: coder];
    }
#if GNU_ARCHIVING
  [coder decodeObjectAt: &super_foo
	 withName: NULL];
#else
  super_foo = [coder decodeObject];
#endif
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

- init
{
  [super init];
  sub_foo = nil;
  label = 0;
  return self;
}

- (void) setSubFoo: o
{
  sub_foo = o;
}

- subFoo
{
  return sub_foo;
}

- (void) encodeWithCoder: coder
{
  printf ("In [Foo encodeWithCoder:]\n");
  [super encodeWithCoder: coder];
  [coder encodeObject: sub_foo];
  [coder encodeValueOfObjCType: @encode(int)
	 at: &label];
}

- initWithCoder: coder
{
  if (decode_substitutes)
    {
      id o = self;
      self = [[[self class] alloc] init];
      [o release];
    }
  else
    {
      self = [super initWithCoder: coder];
    }
  sub_foo = [coder decodeObject];
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
  printf ("Test encoding of forward references\n");
  decode_substitutes = 0;

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
  [foo release];
  [sub_foo release];
  [array release];

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
  printf ("Test encoding of self-referential forward references\n");
  decode_substitutes = 1;

  foo = [[Foo alloc] init];
  [foo setLabel: 4];
  sub_foo = [[SubFoo alloc] initWithSuperFoo: foo label: 3];
  [foo setSubFoo: sub_foo];

  [NSArchiver archiveRootObject: foo toFile: @"fref.dat"];
  printf ("Encoded:  ");
  [sub_foo print];
  [foo release];
  [sub_foo release];

  foo = [NSUnarchiver unarchiveObjectWithFile: @"fref.dat"];
  sub_foo = [foo subFoo];
  printf ("Decoded:  ");
  [sub_foo print];
}

int
main ()
{

#if TEXTCSTREAM
  [Archiver setDefaultCStreamClass: [TextCStream class]];
#endif

  test_fref ();
  test_self_fref ();

#if 0
  printf ("foo 0x%x sub_foo 0x%x\n",
	  (unsigned)foo, (unsigned)sub_foo);
  printf ("sub_foo 0x%x super_foo 0x%x\n",
	  (unsigned)sub_foo, (unsigned)[sub_foo superFoo]);
#endif

  exit (0);
}

/* Test NSArchiver on encoding of self-referential forward references. */

/* This tests an obscure, but important feature of archiving.  GNUstep
   implements it correctly; NeXT does not.  When running in
   NeXT-compatibility mode, (i.e. setting TRY_GNU_ARCHIVING to 0, and
   setting SELF_REF_DECODE_SUBSTITUTES to 1) libgnustep-base crashes
   when trying to use this feature.  When the identical test is
   compiled on a NeXTSTEP machine, it also crashes! */

/* Beginning of some parameters to vary. */
/* Both 1 works; both 0 works.  0 and 1 crash, as does NeXT's */

/* Use GNU Archiving features, if they are available. */
#define TRY_GNU_ARCHIVING 1

/* In the forward self-reference test, -initWithCoder substitutes
   another object for self. */
#define SELF_REF_DECODE_SUBSTITUTES 1

/* End of some parameters to vary. */


#define GNU_ARCHIVING \
(TRY_GNU_ARCHIVING && defined(GNUSTEP_BASE_MAJOR_VERSION))

#if GNU_ARCHIVING
#include <base/Archiver.h>
#endif /* GNU_ARCHIVING */


#ifdef NX_CURRENT_COMPILER_RELEASE
#include <foundation/NSArchiver.h>
#include <foundation/NSArray.h>
#include <foundation/NSAutoreleasePool.h>
#else
#include <Foundation/NSArchiver.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>
#endif

/* Set to 1 to use text coding instead of binary coding */
#define TEXTCSTREAM 1
#if TEXTCSTREAM
#include <base/Archiver.h>
#include <base/TextCStream.h>
#endif

/* The -initWithCoder methods substitutes another object for self. */
static int decode_substitutes;

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
  printf ("\nTest encoding of forward references\n");
  decode_substitutes = 0;

  array = [[NSMutableArray alloc] init];
  foo = [[Foo alloc] init];
  [foo setLabel: 4];
  sub_foo = [[SubFoo alloc] initWithSuperFoo: foo label: 3];
  [foo setSubFoo: sub_foo];
  [array addObject: foo];
  [array insertObject: sub_foo atIndex: 0];

#if GNU_ARCHIVING
  [Archiver archiveRootObject: array toFile: @"fref.dat"];
#else
  [NSArchiver archiveRootObject: array toFile: @"fref.dat"];
#endif
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
  printf ("\nTest encoding of self-referential forward references\n");
  decode_substitutes = SELF_REF_DECODE_SUBSTITUTES;

  foo = [[Foo alloc] init];
  [foo setLabel: 4];
  sub_foo = [[SubFoo alloc] initWithSuperFoo: foo label: 3];
  [foo setSubFoo: sub_foo];

#if GNU_ARCHIVING
  [Archiver archiveRootObject: foo toFile: @"fref.dat"];
#else
  [NSArchiver archiveRootObject: foo toFile: @"fref.dat"];
#endif
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
  id arp = [NSAutoreleasePool new];

#if TEXTCSTREAM
  [Archiver setDefaultCStreamClass: [TextCStream class]];
#endif

  test_fref ();
  test_self_fref ();

  [arp release];

  exit (0);
}

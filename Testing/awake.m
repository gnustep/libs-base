/* Test use of -awakeAfterUsingCoder:
   This is a rather complicated, strenuous test, borrowing elements
   from the fref.m test. */


/* Beginning of some parameters to vary. */
/* 0 and 0 works.  
   1 and 0 works for the first test, but has no way of getting the
     super_foo in second test right, because we haven't resolved the
     forward reference when -awakeAfterUsingCoder is called; this is
     an inherent problem of decoding.
   0 and 1 crashes, as does NeXT's (for reasons related to forward
     references, having nothing to do with awakeAfterUsingCoder). */

/* Use GNU Archiving features, if they are available. */
#define TRY_GNU_ARCHIVING 0

/* In the forward self-reference test, -initWithCoder substitutes
   another object for self. */
#define SELF_REF_INITWITHCODER_SUBSTITUTES 0

/* End of some parameters to vary. */

#ifdef NX_CURRENT_COMPILER_RELEASE
#include <foundation/NSArchiver.h>
#include <foundation/NSArray.h>
#include <foundation/NSAutoreleasePool.h>
#else
#include <Foundation/NSArchiver.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSAutoreleasePool.h>
#endif
#include <Foundation/NSDebug.h>

#define GNU_ARCHIVING \
(TRY_GNU_ARCHIVING && defined(GNUSTEP_BASE_MAJOR_VERSION))

#if GNU_ARCHIVING
#include <base/Archiver.h>
#endif /* GNU_ARCHIVING */


/* The -initWithCoder methods substitutes another object for self. */
int initWithCoder_substitutes;
int Foo_awakeAfterUsingCoder_substitutes = 0;
int SubFoo_awakeAfterUsingCoder_substitutes = 1;

/* This object encodes an -encodeConditionalObject: reference to a Foo. */
@interface SubFoo : NSObject
{
  id super_foo;
  int label;
}
@end

/* This object encodes an -encodeObject: reference to a SubFoo */
/* Object may offer a replacement of itself using -awakeAfterUsingCoder: */
@interface Foo : NSObject
{
  id sub_foo;
  int label;
}
- (int) label;
- (void) setLabel: (int)l;
@end


/* Object may offer a replacement of itself using -awakeAfterUsingCoder: */
@implementation SubFoo

- initWithSuperFoo: o label: (int)l
{
  [super init];
  super_foo = o;
  label = l;
  return self;
}

- awakeAfterUsingCoder: coder
{
  if (SubFoo_awakeAfterUsingCoder_substitutes)
    {
      SubFoo *replacement = [[[self class] alloc]
			      initWithSuperFoo: super_foo
			      label: label + 100];
      /* NOTE: We can't use the ivar SUPER_FOO here because it won't have
	 been resolved by the Decoder yet. */
      [self release];
      return replacement;
    }
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
  if (initWithCoder_substitutes)
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
  printf ("SubFoo label = %d, super label = %d\n",
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

- awakeAfterUsingCoder: coder
{
  if (Foo_awakeAfterUsingCoder_substitutes)
    {
      Foo *replacement = [[[self class] alloc] init];
      [replacement setLabel: label + 100];
      /* NOTE: We can't use the ivar SUPER_FOO here because it won't have
	 been resolved by the Decoder yet. */
      [self release];
      return replacement;
    }
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
  if (initWithCoder_substitutes)
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

- (void) print
{
  printf ("   Foo label = %d,   sub label = %d\n",
	  label, [sub_foo label]);
}

@end

/* Test the use of -encodeConditional to encode a forward reference 
   to an object. */
void
test_fref ()
{
  id array;
  id foo, sub_foo;
  printf ("\nTest awakeAfterUsingCoder substitution of objects that will\n"
	  "   satisfy backward references\n");
  initWithCoder_substitutes = 0;

  array = [[NSMutableArray alloc] init];
  foo = [[Foo alloc] init];
  [foo setLabel: 4];
  sub_foo = [[SubFoo alloc] initWithSuperFoo: nil label: 3];
  [array addObject: foo];
  [array addObject: sub_foo];

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
  foo = [array objectAtIndex: 0];
  sub_foo = [array objectAtIndex: 1];
  printf ("Decoded:  ");
  [sub_foo print];
}

/* Test awakeAfterUsingCoder of a self-referential forward reference. */
void
test_self_fref ()
{
  id foo, sub_foo;
  printf ("\nTest awakeAfterUsingCoder substitution of objects that\n"
	  "   will satisfy self-referential forward references\n");
  initWithCoder_substitutes = SELF_REF_INITWITHCODER_SUBSTITUTES;

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
  id arp;

  arp = [NSAutoreleasePool new];
  [NSAutoreleasePool enableDoubleReleaseCheck:YES];
  GSDebugAllocationActive(YES);

#if TEXTCSTREAM
  [Archiver setDefaultCStreamClass: [TextCStream class]];
#endif

  [arp release];
  arp = [NSAutoreleasePool new];
  printf ("Decoded SubFoo label's should be 100 more than Encoded.\n");
  test_fref ();
  [arp release];
  arp = [NSAutoreleasePool new];
  test_self_fref ();
  [arp release];
  printf("Object allocation info -\n%s\n", GSDebugAllocationList(0));
  exit (0);
}

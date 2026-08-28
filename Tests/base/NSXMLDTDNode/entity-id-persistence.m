/*
 * entity-id-persistence.m - regression test for -[NSXMLDTDNode
 * setNotationName:], -setPublicID: and -setSystemID:.
 *
 * Each setter stored XMLSTRING(arg), i.e. the transient
 * [arg UTF8String] buffer, straight into the persistent libxml2 entity
 * fields (entity->name / ExternalID).  That buffer is owned by the
 * (autoreleased) argument string, so once the pool that produced it
 * drained the field dangled: a later getter read freed memory
 * (AddressSanitizer: heap-use-after-free in -notationName ->
 * StringFromXMLStringPtr -> strlen) and -dealloc's xmlFreeEntity freed
 * a pointer libxml2 never allocated.  -setSystemID: had a second bug: it
 * wrote ExternalID rather than SystemID, so -systemID never returned the
 * value that was set.  The fix copies the argument with XMLStringCopy
 * (as -[NSXMLDTD setPublicID:]/-setSystemID: already do) and stores the
 * system ID in the SystemID field.
 *
 * The setters are reached from ordinary public API, no parsing of
 * untrusted input is required.
 */

#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#import <Foundation/NSXMLNode.h>
#import <Foundation/NSXMLDTDNode.h>
#import "GNUstepBase/GNUstep.h"
#import "GNUstepBase/GSConfig.h"

int main()
{
  START_SET("NSXMLDTDNode entity-declaration IDs persist")
#if !GS_USE_LIBXML
    SKIP("library built without libxml2")
#else
  NSXMLDTDNode	*node;
  NSUInteger	 i;

  node = [[NSXMLDTDNode alloc] initWithKind: NSXMLEntityDeclarationKind
				    options: 0];

  /* Set the three IDs from strings whose lifetime ends with this inner
   * pool, so a setter that failed to copy is left holding freed memory.
   */
  ENTER_POOL
    [node setNotationName: [NSString stringWithFormat: @"gif%d", 89]];
    [node setPublicID: [NSString stringWithFormat: @"-//ACME//DTD %d//EN", 1]];
    [node setSystemID: [NSString stringWithFormat: @"http://acme/%d.dtd", 2]];
  LEAVE_POOL

  /* Churn the allocator so a freed UTF8String buffer is reused: an
   * unbounded copy would now read back something other than the value
   * that was set (in addition to the AddressSanitizer abort).
   */
  ENTER_POOL
    for (i = 0; i < 256; i++)
      {
	(void)[NSString stringWithFormat: @"padpadpadpadpadpad%lu",
	  (unsigned long)i];
      }
  LEAVE_POOL

  PASS_EQUAL([node notationName], @"gif89",
    "setNotationName: copies its argument and it survives the pool")
  PASS_EQUAL([node publicID], @"-//ACME//DTD 1//EN",
    "setPublicID: copies its argument and it survives the pool")
  PASS_EQUAL([node systemID], @"http://acme/2.dtd",
    "setSystemID: stores into the system-ID field and copies its argument")

  [node release];
#endif
  END_SET("NSXMLDTDNode entity-declaration IDs persist")
  return 0;
}

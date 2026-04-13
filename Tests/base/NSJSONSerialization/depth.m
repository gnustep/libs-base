/*
 * depth.m - regression test for NSJSONSerialization recursion depth limit.
 *
 * The JSON parser uses recursive descent for arrays and objects. Before
 * the depth limit was added, pathologically nested input (e.g.
 * [[[...[null]...]]] at a few thousand levels) could exhaust the C stack
 * and crash the process. The parser now tracks its current nesting depth
 * through the ParserState struct and rejects input that would cross a
 * fixed bound with a parse error.
 *
 * This file exercises the depth limit across every entry point that
 * feeds the recursive descent:
 *
 *   - moderately nested documents still parse (20 levels of arrays).
 *   - documents at exactly the default boundary still parse (512 levels).
 *   - documents one level past the boundary are rejected (513 levels).
 *   - documents nested far past the boundary are rejected (2000 levels).
 *   - the bound applies equally to nested objects (not just arrays).
 *   - the bound applies to mixed object/array nesting.
 *   - the bound applies to +JSONObjectWithStream: as well as
 *     +JSONObjectWithData:.
 *   - deeply nested input that is *also* syntactically invalid still
 *     reports an error cleanly (the depth check short-circuits before
 *     the parser dereferences anything that depends on balanced
 *     brackets).
 *
 * The tests are written in ObjC 1.0 syntax - no container literals, no
 * boxed expressions, no blocks, no libobjc2 runtime extensions - so
 * they compile on every Objective-C compiler that GNUstep supports.
 * Each individual assertion is wrapped in an NSAssert so that it
 * surfaces through the NSJSONDepthTests harness' NS_HANDLER and is
 * reported by the PASS macro in main().
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

/* Build a string of the form "[[[ ... [inner] ... ]]]" with `levels`
 * opening brackets, `inner` in the middle, and `levels` closing
 * brackets.
 */
static NSData *
buildNestedArrayJSON(unsigned levels, NSString *inner)
{
  NSMutableString	*s;
  unsigned		i;

  s = [NSMutableString stringWithCapacity: (2 * levels) + [inner length]];
  for (i = 0; i < levels; i++)
    {
      [s appendString: @"["];
    }
  [s appendString: inner];
  for (i = 0; i < levels; i++)
    {
      [s appendString: @"]"];
    }
  return [s dataUsingEncoding: NSUTF8StringEncoding];
}

/* Build a string of the form "{"k":{"k":...{"k":inner}...}}" with
 * `levels` opening objects, `inner` as the innermost value, and
 * `levels` closing braces.
 */
static NSData *
buildNestedObjectJSON(unsigned levels, NSString *inner)
{
  NSMutableString	*s;
  unsigned		i;

  s = [NSMutableString stringWithCapacity: 6 * levels + [inner length]];
  for (i = 0; i < levels; i++)
    {
      [s appendString: @"{\"k\":"];
    }
  [s appendString: inner];
  for (i = 0; i < levels; i++)
    {
      [s appendString: @"}"];
    }
  return [s dataUsingEncoding: NSUTF8StringEncoding];
}

/* Build a string that alternates an object and an array at each
 * nesting level: "{"k":[{"k":[ ... ]}]}", with `levels` of each
 * container type.
 */
static NSData *
buildNestedMixedJSON(unsigned levels, NSString *inner)
{
  NSMutableString	*s;
  unsigned		i;

  s = [NSMutableString stringWithCapacity: 8 * levels + [inner length]];
  for (i = 0; i < levels; i++)
    {
      [s appendString: @"{\"k\":"];
      [s appendString: @"["];
    }
  [s appendString: inner];
  for (i = 0; i < levels; i++)
    {
      [s appendString: @"]"];
      [s appendString: @"}"];
    }
  return [s dataUsingEncoding: NSUTF8StringEncoding];
}

@interface NSJSONDepthTests : NSObject
{
  unsigned	_successes;
  unsigned	_failures;
}
- (BOOL) performTest: (NSString *)name;
@end

@implementation NSJSONDepthTests

- (BOOL) performTest: (NSString *)name
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
  BOOL			result;

  NS_DURING
    {
      [self performSelector: NSSelectorFromString(name)];
      _successes++;
      result = YES;
    }
  NS_HANDLER
    {
      NSLog(@"Test %@ failed: %@", name, [localException reason]);
      _failures++;
      result = NO;
    }
  NS_ENDHANDLER

  [pool release];
  return result;
}

@end

@interface NSJSONDepthTests (Cases)
@end

@implementation NSJSONDepthTests (Cases)

/* 20 levels of arrays is well under any reasonable depth bound and
 * must round-trip cleanly through the parser. */
- (void) moderatelyNestedArrayParses
{
  NSData	*data = buildNestedArrayJSON(20, @"42");
  NSError	*error = nil;
  id		result;

  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  NSAssert(result != nil, @"20-level array returned nil");
  NSAssert(error == nil, @"20-level array populated error out-parameter");
}

/* 20 levels of objects is likewise within bounds. */
- (void) moderatelyNestedObjectParses
{
  NSData	*data = buildNestedObjectJSON(20, @"42");
  NSError	*error = nil;
  id		result;

  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  NSAssert(result != nil, @"20-level object returned nil");
  NSAssert(error == nil, @"20-level object populated error out-parameter");
}

/* A document nested exactly at the default limit must still parse.
 * With NS_JSON_SERIALIZATION_MAX_DEPTH = 512, the parser starts at
 * depth 0 and accepts container entry while `depth < maxDepth`. An
 * input with 512 opening brackets therefore drives `depth` from 0 to
 * 512 across 512 successful entries and is accepted. Test it both for
 * arrays and for objects so that the boundary is verified for both
 * recursive paths.
 */
- (void) boundaryArrayParses
{
  NSData	*data = buildNestedArrayJSON(512, @"null");
  NSError	*error = nil;
  id		result;

  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  NSAssert(result != nil, @"512-level array at boundary returned nil");
  NSAssert(error == nil, @"512-level array populated error out-parameter");
}

- (void) boundaryObjectParses
{
  NSData	*data = buildNestedObjectJSON(512, @"null");
  NSError	*error = nil;
  id		result;

  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  NSAssert(result != nil, @"512-level object at boundary returned nil");
  NSAssert(error == nil, @"512-level object populated error out-parameter");
}

/* One level past the default boundary must be rejected with an error.
 * An input with 513 opening brackets drives `depth` from 0 to 512 on
 * the first 512 entries and then triggers the guard at the 513th
 * entry attempt.
 */
- (void) justOverBoundaryArrayRejected
{
  NSData	*data = buildNestedArrayJSON(513, @"null");
  NSError	*error = nil;
  id		result;

  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  NSAssert(result == nil, @"513-level array was accepted, not rejected");
  NSAssert(error != nil,
    @"513-level array did not populate error out-parameter");
}

- (void) justOverBoundaryObjectRejected
{
  NSData	*data = buildNestedObjectJSON(513, @"null");
  NSError	*error = nil;
  id		result;

  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  NSAssert(result == nil, @"513-level object was accepted, not rejected");
  NSAssert(error != nil,
    @"513-level object did not populate error out-parameter");
}

/* Far past the boundary: 2000 levels. Regardless of how liberal a
 * future depth limit might become, this input should still be
 * rejected.
 */
- (void) pathologicallyNestedArrayRejected
{
  NSData	*data = buildNestedArrayJSON(2000, @"null");
  NSError	*error = nil;
  id		result;

  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  NSAssert(result == nil, @"2000-level array was accepted, not rejected");
  NSAssert(error != nil,
    @"2000-level array did not populate error out-parameter");
}

/* The same bound must apply to mixed object/array nesting: 1000 of
 * each (giving 2000 container levels total) must be rejected.
 */
- (void) mixedDeepNestingRejected
{
  NSData	*data = buildNestedMixedJSON(1000, @"0");
  NSError	*error = nil;
  id		result;

  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  NSAssert(result == nil, @"mixed 1000-level nesting was accepted");
  NSAssert(error != nil,
    @"mixed 1000-level nesting did not populate error out-parameter");
}

/* The stream entry point must honour the same bound. Wrap the same
 * deeply-nested payload in an NSInputStream so that the
 * +JSONObjectWithStream: path is exercised as well as
 * +JSONObjectWithData:.
 */
- (void) streamInterfaceRespectsDepthLimit
{
  NSData		*data = buildNestedArrayJSON(2000, @"null");
  NSInputStream		*stream;
  NSError		*error = nil;
  id			result;

  stream = [NSInputStream inputStreamWithData: data];
  [stream open];
  result = [NSJSONSerialization JSONObjectWithStream: stream
					     options: 0
					       error: &error];
  [stream close];
  NSAssert(result == nil,
    @"JSONObjectWithStream: accepted 2000-level nesting");
  NSAssert(error != nil,
    @"JSONObjectWithStream: did not populate error out-parameter");
}

/* A document that is both deeply nested AND syntactically invalid
 * (600 opening brackets with no matching closing brackets) must still
 * be rejected cleanly via the error out-parameter rather than
 * crashing or returning garbage. The depth guard and the EOF handling
 * are both valid rejection points; the test only requires that one of
 * them fire.
 */
- (void) deepAndMalformedRejected
{
  NSMutableString	*s;
  NSData		*data;
  NSError		*error = nil;
  id			result;
  unsigned		i;

  s = [NSMutableString stringWithCapacity: 600];
  for (i = 0; i < 600; i++)
    {
      [s appendString: @"["];
    }
  /* Deliberately no closing brackets and no inner value. */
  data = [s dataUsingEncoding: NSUTF8StringEncoding];
  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  NSAssert(result == nil, @"deeply-nested malformed JSON was accepted");
  NSAssert(error != nil,
    @"deeply-nested malformed JSON did not populate error out-parameter");
}

@end

int
main(int argc, char *argv[])
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
  NSJSONDepthTests	*tests = [NSJSONDepthTests new];

  START_SET("NSJSONSerialization recursion depth")

  PASS([tests performTest: @"moderatelyNestedArrayParses"],
    "moderately nested array (20 levels) parses successfully")
  PASS([tests performTest: @"moderatelyNestedObjectParses"],
    "moderately nested object (20 levels) parses successfully")
  PASS([tests performTest: @"boundaryArrayParses"],
    "array exactly at the boundary (512 levels) still parses")
  PASS([tests performTest: @"boundaryObjectParses"],
    "object exactly at the boundary (512 levels) still parses")
  PASS([tests performTest: @"justOverBoundaryArrayRejected"],
    "array one level past the boundary (513 levels) is rejected")
  PASS([tests performTest: @"justOverBoundaryObjectRejected"],
    "object one level past the boundary (513 levels) is rejected")
  PASS([tests performTest: @"pathologicallyNestedArrayRejected"],
    "pathologically nested array (2000 levels) is rejected")
  PASS([tests performTest: @"mixedDeepNestingRejected"],
    "deeply nested mixed object/array (1000 levels each) is rejected")
  PASS([tests performTest: @"streamInterfaceRespectsDepthLimit"],
    "JSONObjectWithStream: honours the recursion depth limit")
  PASS([tests performTest: @"deepAndMalformedRejected"],
    "deeply nested malformed JSON reports error without crashing")

  END_SET("NSJSONSerialization recursion depth")

  [tests release];
  [pool release];
  return 0;
}

/*
 * depth.m - regression test for NSJSONSerialization recursion depth limit.
 *
 * The JSON parser uses recursive descent for arrays and objects. Before
 * the depth limit was added, pathologically nested input (e.g.
 * [[[...[null]...]]] at a few thousand levels) could exhaust the stack
 * and crash the process. The parser now tracks its current nesting depth
 * through the ParserState struct and rejects input that would cross a
 * fixed bound with a parse error.
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

#define	ISARRAY(X) [X isKindOfClass: [NSArray class]]
#define	ISDICT(X) [X isKindOfClass: [NSDictionary class]]
#define	ISERROR(X) [X isKindOfClass: [NSError class]]

int
main(int argc, char *argv[])
{
  START_SET("NSJSONSerialization recursion depth")
  NSInputStream		*stream;
  NSData		*data;
  NSError		*error;
  NSMutableString	*s;
  unsigned		i;
  id			result;

  data = buildNestedArrayJSON(20, @"42");
  error = @"dummy";
  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  PASS(ISARRAY(result), "20-level array returned array")
  PASS(error == nil, "20-level array cleared error out-parameter")

  data = buildNestedObjectJSON(20, @"42");
  error = @"dummy";
  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  PASS(ISDICT(result), "20-level object returned dict")
  PASS(error == nil, "20-level object cleared error out-parameter")

  data = buildNestedArrayJSON(512, @"null");
  error = @"dummy";
  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  PASS(ISARRAY(result), "512-level array at boundary returned array")
  PASS(error == nil, "512-level array cleared error out-parameter")

  data = buildNestedObjectJSON(512, @"null");
  error = @"dummy";
  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  PASS(ISDICT(result), "512-level object at boundary returned dict")
  PASS(error == nil, "512-level object cleared error out-parameter")

  data = buildNestedArrayJSON(513, @"null");
  error = @"dummy";
  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  PASS(result == nil, "513-level array at boundary returned nil")
  PASS(ISERROR(error), "513-level array populated error out-parameter")

  data = buildNestedObjectJSON(513, @"null");
  error = @"dummy";
  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  PASS(result == nil, "513-level object at boundary returned nil")
  PASS(ISERROR(error), "513-level object populated error out-parameter")

  data = buildNestedArrayJSON(2000, @"null");
  error = @"dummy";
  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  PASS(result == nil, "2000-level array was rejected")
  PASS(ISERROR(error), "2000-level array populated error out-parameter")


  data = buildNestedMixedJSON(300, @"0");
  error = @"dummy";
  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  PASS(result == nil, "mixed 600-level nesting was rejected")
  PASS(ISERROR(error), "mixed 600-level nesting populated error out-parameter")


  data = buildNestedArrayJSON(2000, @"null");
  error = @"dummy";
  stream = [NSInputStream inputStreamWithData: data];
  [stream open];
  result = [NSJSONSerialization JSONObjectWithStream: stream
					     options: 0
					       error: &error];
  [stream close];
  PASS(result == nil, "JSONObjectWithStream: rejected 2000-level nesting")
  PASS(ISERROR(error), "JSONObjectWithStream: populated error out-parameter")

  /* A document that is both deeply nested AND syntactically invalid
   * (600 opening brackets with no matching closing brackets) must still
   * be rejected cleanly via the error out-parameter rather than
   * crashing or returning garbage. The depth guard and the EOF handling
   * are both valid rejection points; the test only requires that one of
   * them fire.
   */

  s = [NSMutableString stringWithCapacity: 600];
  for (i = 0; i < 600; i++)
    {
      [s appendString: @"["];
    }
  data = [s dataUsingEncoding: NSUTF8StringEncoding];
  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  PASS(result == nil, "deeply-nested malformed JSON was rejected")
  PASS(ISERROR(error),
    "deeply-nested malformed JSON populated error out-parameter")

  END_SET("NSJSONSerialization recursion depth")

  return 0;
}

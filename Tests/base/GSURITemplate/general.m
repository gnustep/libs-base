#if     defined(GNUSTEP_BASE_LIBRARY)
#import "GNUstepBase/GSURITemplate.h"
#import "Testing.h"

/* The json files consist of a dictionary whose names are the names
 * of sets of tests.
 * Each set of tests specifies the 'level' of conformance with RFC6570,
 * The 'variables' to be used for the set of tests, and a 'testcases'
 * array of the individual testcases (which we execute in order).
 * Each testcase is an array of two items:
 * First the template to be tested, and second the expected result.
 * The expected result can be one of three things:
 * A string that the template is expected to expand to.
 * An array of possible expansions (any of which is ok).
 * A boolean false, indicating that the expansion shoudl be nil.
 */
static void
runFile(NSString *name)
{
  NSDictionary	*spec = nil;
  NSData	*data = [NSData dataWithContentsOfFile: name];
  NSString	*key;
  NSError	*e;
  NSEnumerator	*enumerator;

  if (data)
    {
      spec = [NSJSONSerialization JSONObjectWithData: data
					     options: 0
					       error: &e];
    }
  PASS([spec isKindOfClass: [NSDictionary class]],
    "loaded spec '%s' for testing", [name UTF8String])
  if (NO == testPassed) return;

  enumerator = [spec keyEnumerator];
  while ((key = [enumerator nextObject]) != nil)
    {
      NSDictionary	*d = [spec objectForKey: key];
      NSString		*l = [d objectForKey: @"level"];
      NSDictionary	*v = [d objectForKey: @"variables"];
      NSArray		*c = [d objectForKey: @"testcases"];
      NSString		*n;
      const char	*setName;

      n = [NSString stringWithFormat: @"%@ (level %@)", key, l];
      setName = [n UTF8String];
      START_SET(setName)
      NSUInteger	count = [c count];
      NSUInteger	index;

      for (index = 0; index < count; index++)
	{
	  NSArray	*a = [c objectAtIndex: index];
	  NSString	*pattern = [a firstObject];
	  NSString	*result;
	  NSString	*cn;
	  const char	*caseName;
	  id		expect = [a lastObject];
	  GSURITemplate	*t;

	  cn = [n stringByAppendingFormat: @", case %u", (unsigned)index];
	  caseName = [cn UTF8String];
	  t = [GSURITemplate templateWithString: pattern
					  error: &e];
	  result = [t relativeStringWithVariables: v error: &e];
	  if ([expect isKindOfClass: [NSString class]])
	    {
	      PASS_EQUAL(result, expect, "%s", caseName)
	    }
	  else if ([expect isKindOfClass: [NSArray class]])
	    {
	      PASS([expect containsObject: result], "%s", caseName)
	    }
	  else
	    {
	      PASS(result == nil, "%s", caseName)
	    }
	}
      END_SET(setName)
    }
}

int main()
{

  START_SET("errors")
  GSURITemplate	*t;
  NSString	*s;
  NSURL 	*b;
  NSError	*e;
  NSURL		*u;
  NSDictionary	*v;

  b = [NSURL URLWithString:@"http://www.base.org/"];

  e = nil;
  t = [GSURITemplate templateWithString: @"{invalid"
				  error: &e];
  PASS_EQUAL(t, nil, "parse failure returns nil")
  PASS([e code] == GSURITemplateFormatOpenWithoutCloseError,
    "expression opened without close")
  PASS_EQUAL([e localizedDescription],
    @"An expression was opened but never closed.",
    "expected description")
  PASS_EQUAL([e localizedFailureReason],
    @"An opening '{' character was not terminated by a '}' character.",
    "expected reason")
  PASS_EQUAL([[e userInfo] objectForKey: GSURITemplateScanLocationKey],
    [NSNumber numberWithInteger: 8],
    "open without close reported at 8")

  e = nil;
  t = [GSURITemplate templateWithString: @"invalid}"
				  error: &e];
  PASS_EQUAL(t, nil, "parse failure returns nil")
  PASS([e code] == GSURITemplateFormatCloseWithoutOpenError,
    "expression closed without open")
  PASS_EQUAL([e localizedDescription],
    @"An expression was closed that was never opened.",
    "expected description")
  PASS_EQUAL([e localizedFailureReason],
    @"A closing '}' character was encountered that was not preceeded by an opening '{' character.",
    "expected reason")
  PASS_EQUAL([[e userInfo] objectForKey: GSURITemplateScanLocationKey],
    [NSNumber numberWithInteger: 8],
    "close without open reported at 8")


  t = [GSURITemplate templateWithString: @"{variable:1}"
				  error: NULL];
  v = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSArray arrayWithObjects: @"one", @"two", nil ], @"variable",
    nil];
  u = [t URLWithVariables: v relativeToURL: b error: &e];
  PASS_EQUAL(u, nil, "expansion failed")
  PASS([e code] == GSURITemplateExpansionInvalidValueError,
    "variable not expandable")

  t = [GSURITemplate templateWithString: @"{var-name}"
				  error: &e];
  PASS_EQUAL(t, nil, "bad variable name fails parse")
  PASS([e code] == GSURITemplateFormatVariableKeyError,
    "bad variable name produces expected error code")
  PASS_EQUAL([e localizedDescription],
    @"The template contains an invalid variable key.",
    "bad variable name generates description")
  PASS_EQUAL([e localizedFailureReason],
    @"The variable key 'var-name' is invalid.",
    "bad variable name generates reason")


  t = [GSURITemplate templateWithString: @"http://{variable}"
				  error: &e];
  PASS(nil == t, "cannot create instance with bad absolute template")
  PASS([e code] == GSURITemplateFormatAbsolutePartError,
    "correct error code for bad absolute part")

  t = [GSURITemplate templateWithString: @"/path/{variable}"
				  error: &e];
  PASS(t != nil, "setup for nil variables test")
  s = [t relativeStringWithVariables: nil error: &e];
  PASS_EQUAL(s, nil, "nil variables produces nil string")
  PASS([e code] == GSURITemplateExpansionNoVariablesError,
    "nil variables produces nil string")

  END_SET("errors")

  START_SET("success")
  GSURITemplate	*t;
  NSString	*s;
  NSError	*e;
  NSURL 	*b;
  NSDictionary	*v;
  NSURL 	*u;

  v = [NSDictionary dictionaryWithObjectsAndKeys:
    @"value", @"variable",
    nil];

  b = [NSURL URLWithString:@"http://www.base.org/"];
  t = [GSURITemplate templateWithString: @"{variable}"
				  error: &e];
  u = [t URLWithVariables: v relativeToURL: b error: &e];
  PASS_EQUAL([u absoluteString], @"http://www.base.org/value",
   "simple variable substitution works with relative template")
  PASS_EQUAL([u baseURL], b, "base of generated URL matches original")

  u = [t URLWithVariables: v relativeToURL: nil error: &e];
  PASS_EQUAL([u absoluteString], @"value", "creates relative URL without base")

  s = [t relativeStringWithVariables: v error: &e];
  PASS_EQUAL(s, @"value", "simple expansion")

  t = [GSURITemplate templateWithString: @"http://www.base.org/{variable}"
                                  error: &e];
  u = [t URLWithVariables: v relativeToURL: b error: &e];
  PASS_EQUAL([u absoluteString], @"http://www.base.org/value",
   "simple variable substitution works with absolute template")
  PASS_EQUAL([u baseURL], b, "base of generated URL matches original")

  END_SET("success")

  /* Now we run test cases from specifications in json filescopied,
   * with thanks, from CSURITemplater.
   * See the README file fr details.
   */

  runFile(@"spec-examples.json");

  runFile(@"negative-tests.json");

  runFile(@"extended-tests.json");

  return 0;
}
#else
int main(int argc,char **argv)
{
  return 0;
}
#endif

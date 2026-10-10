#import "ObjectTesting.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSExpression.h"
#import "Foundation/NSKeyedArchiver.h"
#import "Foundation/NSPredicate.h"
#import "Foundation/NSString.h"
#import "Foundation/NSValue.h"

/* SUBQUERY(collection, $x, predicate) answers the members of the collection
 * its predicate accepts.
 */
static NSDictionary *
person(NSString *name, int age, NSArray *friends)
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
    name, @"name",
    [NSNumber numberWithInt: age], @"age",
    (friends != nil) ? friends : [NSArray array], @"friends",
    nil];
}

int main(void)
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSDictionary		*alan;
  NSDictionary		*grace;
  NSDictionary		*ada;
  NSDictionary		*loner;
  NSExpression		*subquery;
  NSPredicate		*sociable;
  NSArray		*older;

  alan = person(@"Alan", 41, nil);
  grace = person(@"Grace", 45, nil);
  ada = person(@"Ada", 36, [NSArray arrayWithObjects: alan, grace, nil]);
  loner = person(@"Edsger", 50, nil);

  subquery = [NSExpression expressionForSubquery:
      [NSExpression expressionForKeyPath: @"friends"]
			  usingIteratorVariable: @"f"
				      predicate:
      [NSPredicate predicateWithFormat: @"$f.age > %d", 40]];

  PASS([subquery expressionType] == NSSubqueryExpressionType,
    "a subquery answers NSSubqueryExpressionType");
  PASS_EQUAL([subquery variable], @"f",
    "a subquery answers with its iterator variable");
  PASS_EQUAL([[subquery collection] keyPath], @"friends",
    "a subquery answers with its collection");
  PASS([subquery predicate] != nil,
    "a subquery answers with its predicate");

  older = [subquery expressionValueWithObject: ada context: nil];
  PASS([older count] == 2,
    "a subquery answers the members its predicate accepts");
  PASS([[subquery expressionValueWithObject: loner context: nil] count] == 0,
    "a subquery over an empty collection answers nothing");

  /* The same thing, written the way a format string writes it.  A key path
   * on the iterator variable ($f.age) is a composition, which the parser
   * could not read at all while it asked every expression for a key path.
   */
  PASS(([NSPredicate predicateWithFormat: @"$x.age > %d", 40] != nil),
    "a key path on a variable parses");

  sociable = [NSPredicate predicateWithFormat:
    @"SUBQUERY(friends, $f, $f.age > %d).@count > %d", 40, 1];

  PASS(sociable != nil, "SUBQUERY(...).@count parses");
  PASS([sociable evaluateWithObject: ada],
    "SUBQUERY counts the members its predicate accepts");
  PASS(![sociable evaluateWithObject: alan],
    "SUBQUERY answers nothing for a member with no such friends");
  PASS([[sociable predicateFormat] hasPrefix: @"SUBQUERY(friends, $f,"],
    "a subquery prints back the way it was written");

  /* Inside the subquery, a key path is the object's the subquery belongs
   * to, and the member is reached through the variable: friends older than
   * the person whose friends they are.
   */
  PASS([[NSPredicate predicateWithFormat:
    @"SUBQUERY(friends, $f, $f.age > age).@count == 2"] evaluateWithObject: ada],
    "a key path in a subquery is the outer object's");
  PASS([[NSPredicate predicateWithFormat:
    @"SUBQUERY(friends, $f, $f.name == \"Grace\" AND $f.age > age).@count == 1"]
    evaluateWithObject: ada],
    "the variable and the outer object's key paths mix");

  /* And it survives an archive, which a subquery whose predicate holds a
   * key path composition could not do before either.
   */
  PASS_EQUAL([NSKeyedUnarchiver unarchiveObjectWithData:
    [NSKeyedArchiver archivedDataWithRootObject: subquery]], subquery,
    "a subquery survives an archive");

  [arp release];
  return 0;
}

/* Interface for NSPredicate for GNUStep
   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by:  Dr. H. Nikolaus Schaller
   Created: 2005
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */ 

#include <Foundation/NSComparisonPredicate.h>
#include <Foundation/NSCompoundPredicate.h>
#include <Foundation/NSExpression.h>
#include <Foundation/NSPredicate.h>

#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSException.h>
#include <Foundation/NSKeyValueCoding.h>
#include <Foundation/NSNull.h>
#include <Foundation/NSScanner.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>

#include <stdarg.h>

#define	NIMP	  [NSException raise: NSGenericException \
  format: @"%s(%s) has not implemented %s",\
  GSClassNameFromObject(self), GSObjCIsInstance(self) ? "instance" : "class",\
  GSNameFromSelector(_cmd)]

@interface GSPredicateScanner : NSScanner
{
  NSEnumerator	*_args;		// Not retained.
  va_list	_vargs;
  unsigned	_retrieved;
}

- (id) initWithString: (NSString*)format
		 args: (NSArray*)args;
- (id) initWithString: (NSString*)format
		vargs: (va_list)vargs;
- (id) nextArg;
- (BOOL) scanPredicateKeyword: (NSString *) key;
- (NSPredicate *) parse;
- (NSPredicate *) parsePredicate;
- (NSPredicate *) parseAnd;
- (NSPredicate *) parseNot;
- (NSPredicate *) parseOr;
- (NSPredicate *) parseComparison;
- (NSExpression *) parseExpression;
- (NSExpression *) parseFunctionalExpression;
- (NSExpression *) parsePowerExpression;
- (NSExpression *) parseMultiplicationExpression;
- (NSExpression *) parseAdditionExpression;
- (NSExpression *) parseBinaryExpression;

@end

@interface GSTruePredicate : NSPredicate
@end

@interface GSFalsePredicate : NSPredicate
@end

@interface GSAndCompoundPredicate : NSCompoundPredicate
{
  @public
  NSArray	*_subs;
}
- (id) _initWithSubpredicates: (NSArray *)list;
@end

@interface GSOrCompoundPredicate : NSCompoundPredicate
{
  @public
  NSArray	*_subs;
}
- (id) _initWithSubpredicates: (NSArray *)list;
@end

@interface GSNotCompoundPredicate : NSCompoundPredicate
{
  @public
  NSPredicate	*_sub;
}
- (id) _initWithSubpredicate: (id)predicateOrList;
@end

@interface GSConstantValueExpression : NSExpression
{
  @public
  id	_obj;
}
@end

@interface GSEvaluatedObjectExpression : NSExpression
@end

@interface GSVariableExpression : NSExpression
{
  @public
  NSString	*_variable;
}
@end

@interface GSKeyPathExpression : NSExpression
{
  @public
  NSString	*_keyPath;
}
@end

@interface GSFunctionExpression : NSExpression
{
  @public
  NSString		*_function;
  NSArray		*_args;
  NSMutableArray	*_eargs;    // temporary space 
  unsigned int		_argc;
  SEL _selector;
}
@end



@implementation NSPredicate

+ (NSPredicate *) predicateWithFormat: (NSString *) format, ...
{
  NSPredicate	*p;
  va_list	va;

  va_start (va, format);
  p = [self predicateWithFormat: format arguments: va];
  va_end (va);
  return p;
}

+ (NSPredicate *) predicateWithFormat: (NSString *)format
			argumentArray: (NSArray *)args
{
  GSPredicateScanner	*s;
  NSPredicate		*p;

  s = [[GSPredicateScanner alloc] initWithString: format
					    args: args];
  p = [s parse];
  RELEASE(s);
  return p;
}

+ (NSPredicate *) predicateWithFormat: (NSString *)format
			    arguments: (va_list)args
{
  GSPredicateScanner	*s;
  NSPredicate		*p;

  s = [[GSPredicateScanner alloc] initWithString: format
					   vargs: args];
  p = [s parse];
  RELEASE(s);
  return p;
}

+ (NSPredicate *) predicateWithValue: (BOOL)value
{
  if (value)
    {
      return (NSPredicate *)[GSTruePredicate new];
  }
  return (NSPredicate *)[GSFalsePredicate new];
}

// we don't ever instantiate NSPredicate

- (id) copyWithZone: (NSZone *)z
{
  [self subclassResponsibility: _cmd];
  return RETAIN(self);
}

- (BOOL) evaluateWithObject: (id)object
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (NSString *) description
{
  return [self predicateFormat];
}

- (NSString *) predicateFormat
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSPredicate *) predicateWithSubstitutionVariables: (NSDictionary *)variables
{
  return [[self copy] autorelease];  
}

- (void) encodeWithCoder: (NSCoder *) coder;
{
  [self subclassResponsibility: _cmd];
}

- (id) initWithCoder: (NSCoder *) coder;
{
  [self subclassResponsibility: _cmd];
  return self;
}

@end

@implementation GSTruePredicate
- (id) copyWithZone: (NSZone *) z
{
  return [self retain];
}

- (BOOL) evaluateWithObject: (id)object
{
  return YES;
}

- (NSString *) predicateFormat
{
  return @"TRUEPREDICATE";
}
@end

@implementation GSFalsePredicate
- (id) copyWithZone: (NSZone *)z
{
  return [self retain];
}

- (BOOL) evaluateWithObject: (id)object
{
  return NO;
}

- (NSString *) predicateFormat
{
  return @"FALSEPREDICATE";
}
@end

@implementation NSCompoundPredicate

+ (NSPredicate *) andPredicateWithSubpredicates: (NSArray *)list
{
  return [[[GSAndCompoundPredicate alloc] _initWithSubpredicates: list]
    autorelease];
}

+ (NSPredicate *) notPredicateWithSubpredicate: (NSPredicate *)predicate
{
  return [[[GSNotCompoundPredicate alloc] _initWithSubpredicate: predicate]
    autorelease];
}

+ (NSPredicate *) orPredicateWithSubpredicates: (NSArray *)list
{
  return [[[GSOrCompoundPredicate alloc] _initWithSubpredicates: list]
    autorelease];
}

- (NSCompoundPredicateType) compoundPredicateType
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (id) initWithType: (NSCompoundPredicateType)type
      subpredicates: (NSArray *)list
{
  [self release];
  switch (type)
    {
      case NSAndPredicateType: 
	return [[GSAndCompoundPredicate alloc] _initWithSubpredicates: list];
      case NSOrPredicateType: 
	return [[GSOrCompoundPredicate alloc] _initWithSubpredicates: list];
      case NSNotPredicateType: 
	return [[GSNotCompoundPredicate alloc] _initWithSubpredicate: list];
      default: 
	return nil;
    }
}

- (id) copyWithZone: (NSZone *)z
{
  [self subclassResponsibility: _cmd];
  return [self retain];
}

- (NSArray *) subpredicates
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [self subclassResponsibility: _cmd];
}

- (id) initWithCoder: (NSCoder *)coder
{
  return self;
}

@end

@implementation GSAndCompoundPredicate

- (id) _initWithSubpredicates: (NSArray *)list
{
  NSAssert ([list count] > 1, NSInvalidArgumentException);
  if ((self = [super init]) != nil)
    {
      _subs = [list retain];
    }
  return self;
}

- (void) dealloc
{
  [_subs release];
  [super dealloc];
}

- (NSCompoundPredicateType) compoundPredicateType
{
  return NSAndPredicateType;
}

- (BOOL) evaluateWithObject: (id) object
{
  NSEnumerator	*e = [_subs objectEnumerator];
  NSPredicate	*p;

  while ((p = [e nextObject]) != nil)
    {
      if ([p evaluateWithObject: object] == NO)
	{
	  return NO;  // any NO returns NO
	}
    }
  return YES;  // all are true
}

- (NSString *) predicateFormat
{
  NSString	*fmt = @"";
  NSEnumerator	*e = [_subs objectEnumerator];
  NSPredicate	*sub;
  unsigned	cnt = 0;

  while ((sub = [e nextObject]) != nil)
    {
      // when to add ()? -> if sub is compound and of type "or"
      if (cnt == 0)
	{
	  fmt = [sub predicateFormat];  // first
	}
      else
	{
	  if (cnt == 1
	    && [[_subs objectAtIndex: 0]
	      isKindOfClass: [NSCompoundPredicate class]]
	    && [(NSCompoundPredicate *)[_subs objectAtIndex: 0]
	      compoundPredicateType] == NSOrPredicateType)
	    {
	      // we need () around first OR on left side
	      fmt = [NSString stringWithFormat: @"(%@)", fmt]; 
	    }
	  if ([sub isKindOfClass: [NSCompoundPredicate class]]
	    && [(NSCompoundPredicate *) sub compoundPredicateType]
	      == NSOrPredicateType)
	    {
	      // we need () around right OR
	      fmt = [NSString stringWithFormat: @"%@ AND (%@)",
		fmt, [sub predicateFormat]];
	    }
	  else
	    {
	      fmt = [NSString stringWithFormat: @"%@ AND %@",
		fmt, [sub predicateFormat]];
	    }
	}
      cnt++;
    }
  return fmt;
}

- (NSArray *) subpredicates
{
  return _subs;
}

- (NSPredicate *) predicateWithSubstitutionVariables: (NSDictionary *)variables
{
  GSAndCompoundPredicate	*copy = [self copy];
  unsigned int			count = [copy->_subs count];
  unsigned int			i;

  for (i = 0; i < count; i++)
    {
      NSPredicate	*rep;

      rep = [_subs objectAtIndex: i];
      rep = [rep predicateWithSubstitutionVariables: variables];
      [(NSMutableArray *)(copy->_subs) replaceObjectAtIndex: i
						 withObject: rep];
    }
  return [copy autorelease];  
}

@end

@implementation GSOrCompoundPredicate

- (id) _initWithSubpredicates: (NSArray *)list
{
  NSAssert ([list count] > 1, NSInvalidArgumentException);
  if ((self = [super init]) != nil)
    {
      _subs = [list retain];
    }
  return self;
}

- (void) dealloc
{
  [_subs release];
  [super dealloc];
}

- (NSCompoundPredicateType) compoundPredicateType
{
  return NSOrPredicateType;
}

- (BOOL) evaluateWithObject: (id)object
{
  NSEnumerator	*e = [_subs objectEnumerator];
  NSPredicate	*p;

  while ((p = [e nextObject]) != nil)
    {
      if ([p evaluateWithObject: object] == YES)
	{
	  return YES;  // any YES returns YES
	}
    }
  return NO;  // none is true
}

- (NSString *) predicateFormat
{
  NSString	*fmt = @"";
  NSEnumerator	*e = [_subs objectEnumerator];
  NSPredicate	*sub;

  while ((sub = [e nextObject]) != nil)
    {
      if ([fmt length] > 0)
	{
	  fmt = [NSString stringWithFormat: @"%@ OR %@",
	    fmt, [sub predicateFormat]];
	}
      else
	{
	  fmt = [sub predicateFormat];  // first
	}
    }
  return fmt;
}

- (NSArray *) subpredicates
{
  return _subs;
}

- (NSPredicate *) predicateWithSubstitutionVariables: (NSDictionary *)variables
{
  GSOrCompoundPredicate	*copy = [self copy];
  unsigned int			count = [copy->_subs count];
  unsigned int			i;

  for (i = 0; i < count; i++)
    {
      NSPredicate	*rep;

      rep = [_subs objectAtIndex: i];
      rep = [rep predicateWithSubstitutionVariables: variables];
      [(NSMutableArray *)(copy->_subs) replaceObjectAtIndex: i withObject: rep];
    }
  return [copy autorelease];  
}

@end

@implementation GSNotCompoundPredicate

- (id) _initWithSubpredicate: (id)listOrPredicate
{
  if ((self = [super init]) != nil)
    {
      if ([listOrPredicate isKindOfClass: [NSArray class]])
	{
	  _sub = [[listOrPredicate objectAtIndex: 0] retain];
	}
      else
	{
	  _sub = [listOrPredicate retain];
	}
    }
  return self;
}

- (void) dealloc
{
  [_sub release];
  [super dealloc];
}

- (NSCompoundPredicateType) compoundPredicateType
{
  return NSNotPredicateType;
}

- (BOOL) evaluateWithObject: (id)object
{
  return ![_sub evaluateWithObject: object];
}

- (NSString *) predicateFormat
{
  if ([_sub isKindOfClass: [NSCompoundPredicate class]]
    && [(NSCompoundPredicate *)_sub compoundPredicateType]
      != NSNotPredicateType)
    {
      return [NSString stringWithFormat: @"NOT(%@)", [_sub predicateFormat]];
    }
  return [NSString stringWithFormat: @"NOT %@", [_sub predicateFormat]];
}

- (NSArray *) subpredicates
{
  return [NSArray arrayWithObject: _sub];
}

- (NSPredicate *) predicateWithSubstitutionVariables: (NSDictionary *)variables
{
  GSNotCompoundPredicate	*copy = [self copy];

  copy->_sub = [_sub predicateWithSubstitutionVariables: variables];
  return [copy autorelease];  
}

@end

@implementation NSComparisonPredicate

+ (NSPredicate *) predicateWithLeftExpression: (NSExpression *)left
			      rightExpression: (NSExpression *)right
			       customSelector: (SEL) sel
{
  return [[[self alloc] initWithLeftExpression: left
    rightExpression: right customSelector: sel] autorelease];
}

+ (NSPredicate *) predicateWithLeftExpression: (NSExpression *)left
  rightExpression: (NSExpression *)right
  modifier: (NSComparisonPredicateModifier)modifier
  type: (NSPredicateOperatorType)type
  options: (unsigned)opts
{
  return [[[self alloc] initWithLeftExpression: left rightExpression: right
    modifier: modifier type: type options: opts] autorelease];
}

- (NSComparisonPredicateModifier) comparisonPredicateModifier
{
  return _modifier;
}

- (SEL) customSelector
{
  return _selector;
}

- (NSPredicate *) initWithLeftExpression: (NSExpression *)left
			 rightExpression: (NSExpression *)right
			  customSelector: (SEL)sel
{
  if ((self = [super init]) != nil)
    {
      _left = [left retain];
      _right = [right retain];
      _selector = sel;
      _type = NSCustomSelectorPredicateOperatorType;
    }
  return self;
}

- (id) initWithLeftExpression: (NSExpression *)left
	      rightExpression: (NSExpression *)right
		     modifier: (NSComparisonPredicateModifier)modifier
			 type: (NSPredicateOperatorType)type
		      options: (unsigned)opts
{
  if ((self = [super init]) != nil)
    {
      _left = [left retain];
      _right = [right retain];
      _modifier = modifier;
      _type = type;
      _options = opts;
    }
  return self;
}

- (void) dealloc;
{
  [_left release];
  [_right release];
  [super dealloc];
}

- (NSExpression *) leftExpression
{
  return _left;
}

- (unsigned) options
{
  return _options;
}

- (NSPredicateOperatorType) predicateOperatorType
{
  return _type;
}

- (NSExpression *) rightExpression
{
  return _right;
}

- (NSString *) predicateFormat
{
  NSString	*modi = @"";
  NSString	*comp = @"?comparison?";
  NSString	*opt = @"";

  switch (_modifier)
    {
      case NSDirectPredicateModifier:
	break;
      case NSAnyPredicateModifier:
	modi = @"ANY "; break;
      case NSAllPredicateModifier:
	modi = @"ALL"; break;
      default:
	modi = @"?modifier?"; break;
    }
  switch (_type)
    {
      case NSLessThanPredicateOperatorType:
	comp = @"<"; break;
      case NSLessThanOrEqualToPredicateOperatorType:
	comp = @"<="; break;
      case NSGreaterThanPredicateOperatorType:
	comp = @">="; break;
      case NSGreaterThanOrEqualToPredicateOperatorType:
	comp = @">"; break;
      case NSEqualToPredicateOperatorType:
	comp = @"="; break;
      case NSNotEqualToPredicateOperatorType:
	comp = @"!="; break;
      case NSMatchesPredicateOperatorType:
	comp = @"MATCHES"; break;
      case NSLikePredicateOperatorType:
	comp = @"LIKE"; break;
      case NSBeginsWithPredicateOperatorType:
	comp = @"BEGINSWITH"; break;
      case NSEndsWithPredicateOperatorType:
	comp = @"ENDSWITH"; break;
      case NSInPredicateOperatorType:
	comp = @"IN"; break;
      case NSCustomSelectorPredicateOperatorType: 
	{
	  comp = NSStringFromSelector (_selector);
	}
    }
  switch (_options)
    {
      case NSCaseInsensitivePredicateOption:
	opt = @"[c]"; break;
      case NSDiacriticInsensitivePredicateOption:
	opt = @"[d]"; break;
      case NSCaseInsensitivePredicateOption
	| NSDiacriticInsensitivePredicateOption:
	opt = @"[cd]"; break;
      default:
	opt = @"[?options?]"; break;
    }
  return [NSString stringWithFormat: @"%@%@ %@%@ %@",
   modi, _left, comp, opt, _right];
}

- (NSPredicate *) predicateWithSubstitutionVariables: (NSDictionary *)variables
{
  NSComparisonPredicate	*copy = [self copy];

  // FIXME ... perform substitution in the left and right expressions
  return [copy autorelease];  
}

@end

@implementation NSExpression

+ (NSExpression *) expressionForConstantValue: (id)obj
{
  GSConstantValueExpression *e;

  e = [[[GSConstantValueExpression alloc] init] autorelease];
  e->_obj = [obj retain];
  return e;
}

+ (NSExpression *) expressionForEvaluatedObject
{
  return [[[GSEvaluatedObjectExpression alloc] init] autorelease];
}

+ (NSExpression *) expressionForFunction: (NSString *)name
			       arguments: (NSArray *)args
{
  GSFunctionExpression	*e;
  NSString		*s;

  e = [[[GSFunctionExpression alloc] init] autorelease];
  s = [NSString stringWithFormat: @"_eval_%@: context: ", name];
  e->_selector = NSSelectorFromString(s);
  if (![e respondsToSelector: e->_selector])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Unknown function implementation: %@", name];
    }
  e->_function = [name retain];
  e->_argc = [args count];
  e->_args = [args retain];
  e->_eargs = [args copy];  // space for evaluated arguments
  return e;
}

+ (NSExpression *) expressionForKeyPath: (NSString *)path
{
  GSKeyPathExpression *e;

  if (![path isKindOfClass: [NSString class]])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Keypath is not NSString: %@", path];
    }
  e = [[[GSKeyPathExpression alloc] init] autorelease];
  e->_keyPath = [path retain];
  return e;
}

+ (NSExpression *) expressionForVariable: (NSString *)string
{
  GSVariableExpression *e;

  e = [[[GSVariableExpression alloc] init] autorelease];
  e->_variable = [string retain];
  return e;
}

- (NSArray *) arguments
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) constantValue
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSString *) description
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSExpressionType) expressionType
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (id) expressionValueWithObject: (id)object
			 context: (NSMutableDictionary *)context
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSString *) function
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSString *) keyPath
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSExpression *) operand
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSString *) variable
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) initWithExpressionType: (NSExpressionType)type
{
  [self release];
  switch (type)
    {
      case NSConstantValueExpressionType: 
	return [[GSConstantValueExpression alloc] init];
      case NSEvaluatedObjectExpressionType: 
	return [[GSEvaluatedObjectExpression alloc] init];
      case NSVariableExpressionType: 
	return [[GSVariableExpression alloc] init];
      case NSKeyPathExpressionType: 
	return [[GSKeyPathExpression alloc] init];
      case NSFunctionExpressionType: 
	return [[GSFunctionExpression alloc] init];
      default: 
	return nil;
   
    }
}

- (id) copyWithZone: (NSZone *)z
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [self subclassResponsibility: _cmd];
}

- (id) initWithCoder: (NSCoder *)coder
{
  [self subclassResponsibility: _cmd];
  return nil;
}

@end

@implementation GSConstantValueExpression

- (NSArray *) arguments
{
  return nil;
}

- (id) constantValue
{
  return _obj;
}

- (NSString *) description
{
  return _obj;
}

- (NSExpressionType) expressionType
{
  return NSConstantValueExpressionType;
}

- (id) expressionValueWithObject: (id)object
			 context: (NSMutableDictionary *)context
{
  return _obj;
}

- (NSString *) function
{
  return nil;
}

- (NSString *) keyPath
{
  return nil;
}

- (NSExpression *) operand
{
  return nil;
}

- (NSString *) variable
{
  return nil;
}

- (void) dealloc
{
  [_obj release];
  [super dealloc];
}

@end

@implementation GSEvaluatedObjectExpression

- (NSArray *) arguments
{
  return nil;
}

- (id) constantValue
{
  return nil;
}

- (NSString *) description
{
  return @"SELF";
}

- (NSExpressionType) expressionType
{
  return NSEvaluatedObjectExpressionType;
}

- (id) expressionValueWithObject: (id)object
			 context: (NSMutableDictionary *)context
{
  return self;
}

- (NSString *) function
{
  return nil;
}

- (NSString *) keyPath
{
  return nil;
}

- (NSExpression *) operand
{
  return nil;
}

- (NSString *) variable
{
  return nil;
}

@end

@implementation GSVariableExpression

- (NSArray *) arguments
{
  return nil;
}

- (id) constantValue
{
  return nil;
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"$%@", _variable];
}

- (NSExpressionType) expressionType
{
  return NSVariableExpressionType;
}

- (id) expressionValueWithObject: (id)object
			 context: (NSMutableDictionary *)context
{
  return [context objectForKey: _variable];
}

- (NSString *) function
{
  return nil;
}

- (NSString *) keyPath
{
  return nil;
}

- (NSExpression *) operand
{
  return nil;
}

- (NSString *) variable
{
  return _variable;
}

- (void) dealloc;
{
  [_variable release];
  [super dealloc];
}

@end

@implementation GSKeyPathExpression

- (NSArray *) arguments
{
  return nil;
}

- (id) constantValue
{
  return nil;
}

- (NSString *) description
{
  return _keyPath;
}

- (NSExpressionType) expressionType
{
  return NSKeyPathExpressionType;
}

- (id) expressionValueWithObject: (id)object
			 context: (NSMutableDictionary *)context
{
  return [object valueForKeyPath: _keyPath];
}

- (NSString *) function
{
  return nil;
}

- (NSString *) keyPath
{
  return _keyPath;
}

- (NSExpression *) operand
{
  return nil;
}

- (NSString *) variable
{
  return nil;
}

- (void) dealloc;
{
  [_keyPath release];
  [super dealloc];
}

@end

@implementation GSFunctionExpression

- (NSArray *) arguments
{
  return _args;
}

- (id) constantValue
{
  return nil;
}

- (NSString *) description
{
  // here we should recognize binary and unary operators
  // and convert back to standard format
  // and add parentheses if required
  return [NSString stringWithFormat: @"%@(%@)",
    [NSStringFromSelector (_selector) substringFromIndex: 6], _args];
}

- (NSExpressionType) expressionType
{
  return NSFunctionExpressionType;
}

- (id) expressionValueWithObject: (id)object
			 context: (NSMutableDictionary *)context
{ // apply method selector
  unsigned int i;

  for (i = 0; i < _argc; i++)
    {
      id	o;

      o = [_args objectAtIndex: i];
      o = [o expressionValueWithObject: object context: context];
      [_eargs replaceObjectAtIndex: i withObject: o];
    }
  return [self performSelector: _selector
		    withObject: object
		    withObject: context];
}

- (id) _eval__chs: (id)object context: (NSMutableDictionary *)context
{
  return [NSNumber numberWithInt: -[[_eargs objectAtIndex: 0] intValue]];
}

- (id) _eval__first: (id)object context: (NSMutableDictionary *)context
{
  return [[_eargs objectAtIndex: 0] objectAtIndex: 0];
}

- (id) _eval__last: (id)object context: (NSMutableDictionary *)context
{
  return [[_eargs objectAtIndex: 0] lastObject];
}

- (id) _eval__index: (id)object context: (NSMutableDictionary *)context
{
  if ([[_eargs objectAtIndex: 0] isKindOfClass: [NSDictionary class]])
    return [[_eargs objectAtIndex: 0] objectForKey: [_eargs objectAtIndex: 1]];
  return [[_eargs objectAtIndex: 0] objectAtIndex: [[_eargs objectAtIndex: 1] unsignedIntValue]];  // raises exception if invalid
}

- (id) _eval_count: (id)object context: (NSMutableDictionary *)context
{
  if (_argc != 1)
    ;  // error
  return [NSNumber numberWithUnsignedInt: [[_eargs objectAtIndex: 0] count]];
}

- (id) _eval_avg: (NSArray *)expressions
	 context: (NSMutableDictionary *)context
{
  NIMP;
  return [NSNumber numberWithDouble: 0.0];
}

- (id) _eval_sum: (NSArray *)expressions
	 context: (NSMutableDictionary *)context
{
  NIMP;
  return [NSNumber numberWithDouble: 0.0];
}

- (id) _eval_min: (NSArray *)expressions
	 context: (NSMutableDictionary *)context
{
  NIMP;
  return [NSNumber numberWithDouble: 0.0];
}

- (id) _eval_max: (NSArray *)expressions
	 context: (NSMutableDictionary *)context
{
  NIMP;
  return [NSNumber numberWithDouble: 0.0];
}

// add arithmetic functions: average, median, mode, stddev, sqrt, log, ln, exp, floor, ceiling, abs, trunc, random, randomn, now

- (NSString *) function
{
  return _function;
}

- (NSString *) keyPath
{
  return nil;
}

- (NSExpression *) operand
{
  return nil;
}

- (NSString *) variable
{
  return nil;
}

- (void) dealloc;
{
  [_args release];
  [_eargs release];
  [_function release];
  [super dealloc];
}

@end

@implementation NSArray (NSPredicate)

- (NSArray *) filteredArrayUsingPredicate: (NSPredicate *)predicate
{
  NSMutableArray	*result;

  NSEnumerator		*e = [self objectEnumerator];
  id			object;

  result = [NSMutableArray arrayWithCapacity: [self count]];
  while ((object = [e nextObject]) != nil)
    {
      if ([predicate evaluateWithObject: object] == YES)
	{
	  [result addObject: object];  // passes filter
	}
    }
  return result;  // we could/should convert to a non-mutable copy
}

@end

@implementation GSPredicateScanner

- (id) initWithString: (NSString*)format
		 args: (NSArray*)args
{
  self = [super initWithString: format];
  if (self != nil)
    {
      _args = [args objectEnumerator];
    }
  return self;
}

- (id) initWithString: (NSString*)format
		vargs: (va_list)vargs
{
  self = [super initWithString: format];
  if (self != nil)
    {
#ifdef __va_copy
      __va_copy(_vargs, vargs);
#else
      _vargs = vargs;
#endif
    }
  return self;
}

- (id) nextArg
{
  id	o;

  if (_args != nil)
    {
      o = [_args nextObject];
    }
  else
    {
      unsigned	i;
      va_list	ap;

#ifdef __va_copy
      __va_copy(ap, _vargs);
#else
      ap = _vargs;
#endif

      for (i = 0; i < _retrieved; i++)
        {
	  o = va_arg(ap, id);
        }
      _retrieved++;
      o = va_arg(ap, id);
    }
  return o;
}

- (BOOL) scanPredicateKeyword: (NSString *)key
{
  // save to back up
  unsigned loc = [self scanLocation];
  unichar c;
  
  [self setCaseSensitive: NO];
  if (![self scanString: key intoString: NULL])
    {
      // no match
      return NO;
    }
  c = [[self string] characterAtIndex: [self scanLocation]];
  if (![[NSCharacterSet alphanumericCharacterSet] characterIsMember: c])
    {
      // ok
      return YES;
    }

  // back up
  [self setScanLocation: loc];
  // no match
  return NO;
}

- (NSPredicate *) parse
{
  NSPredicate *r;

  r = [self parsePredicate];
  if (![self isAtEnd])
    {
      [NSException raise: NSInvalidArgumentException 
		  format: @"Format string contains extra characters: \"%@\"", 
		   [self string]];
    }
  return r;
}

- (NSPredicate *) parsePredicate
{
  return [self parseAnd];
}

- (NSPredicate *) parseAnd
{
  NSPredicate	*l = [self parseOr];

  while ([self scanPredicateKeyword: @"AND"])
    {
      NSPredicate	*r = [self parseOr];

      if ([r isKindOfClass: [NSCompoundPredicate class]]
	&& [(NSCompoundPredicate *)r compoundPredicateType]
	== NSAndPredicateType)
        {
	  // merge
	  if ([l isKindOfClass:[NSCompoundPredicate class]]
	    && [(NSCompoundPredicate *)l compoundPredicateType]
	    == NSAndPredicateType)
	    {
	      [(NSMutableArray *)[(NSCompoundPredicate *)l subpredicates] 
		addObjectsFromArray: [(NSCompoundPredicate *)r subpredicates]];
	    }
	  else
	    {
	      [(NSMutableArray *)[(NSCompoundPredicate *)r subpredicates] 
		insertObject: l atIndex: 0];
	      l = r;
	    }
	}
      else if ([l isKindOfClass: [NSCompoundPredicate class]]
	&& [(NSCompoundPredicate *)l compoundPredicateType]
	== NSAndPredicateType)
        {
	  // add to l
	  [(NSMutableArray *)[(NSCompoundPredicate *)l subpredicates]
	    addObject: r];
	}
      else
        {
	  l = [NSCompoundPredicate andPredicateWithSubpredicates: 
	    [NSArray arrayWithObjects:l, r, nil]];
	}
    }
  return l;
}

- (NSPredicate *) parseNot
{
  if ([self scanString: @"(" intoString: NULL])
    {
      NSPredicate *r = [self parsePredicate];
	
      if (![self scanString: @")" intoString: NULL])
        {
	  [NSException raise: NSInvalidArgumentException 
		      format: @"Missing ) in compound predicate"];
	}
      return r;
    }

  if ([self scanPredicateKeyword: @"NOT"])
    {
      // -> NOT NOT x or NOT (y)
      return [NSCompoundPredicate
	notPredicateWithSubpredicate: [self parseNot]];
    }

  if ([self scanPredicateKeyword: @"TRUEPREDICATE"])
    {
      return [NSPredicate predicateWithValue: YES];
    }
  if ([self scanPredicateKeyword: @"FALSEPREDICATE"])
    {
      return [NSPredicate predicateWithValue: NO];
    }
  
  return [self parseComparison];
}

- (NSPredicate *) parseOr
{
  NSPredicate	*l = [self parseNot];

  while ([self scanPredicateKeyword: @"OR"])
    {
      NSPredicate	*r = [self parseNot];

      if ([r isKindOfClass: [NSCompoundPredicate class]]
	&& [(NSCompoundPredicate *)r compoundPredicateType]
	== NSOrPredicateType)
        {
	  // merge
	  if ([l isKindOfClass: [NSCompoundPredicate class]]
	    && [(NSCompoundPredicate *)l compoundPredicateType]
	    == NSOrPredicateType)
	    {
	      [(NSMutableArray *)[(NSCompoundPredicate *)l subpredicates] 
	        addObjectsFromArray: [(NSCompoundPredicate *)r subpredicates]];
	    }
	  else
	    {
	      [(NSMutableArray *)[(NSCompoundPredicate *)r subpredicates] 
	        insertObject: l atIndex: 0];
	      l = r;
	    }		
	}
      else if ([l isKindOfClass: [NSCompoundPredicate class]]
	&& [(NSCompoundPredicate *)l compoundPredicateType]
	== NSOrPredicateType)
        {
	  [(NSMutableArray *) [(NSCompoundPredicate *) l subpredicates]
	     addObject:r];
	}
      else
        {
	  l = [NSCompoundPredicate orPredicateWithSubpredicates: 
	    [NSArray arrayWithObjects: l, r, nil]];
	}
    }
  return l;
}

- (NSPredicate *) parseComparison
{ 
  // there must always be a comparison
  NSComparisonPredicateModifier modifier = NSDirectPredicateModifier;
  NSPredicateOperatorType type = 0;
  unsigned opts = 0;
  NSExpression *left;
  NSPredicate *p;
  BOOL negate = NO;

  if ([self scanPredicateKeyword: @"ANY"])
    {
      modifier = NSAnyPredicateModifier;
    }
  else if ([self scanPredicateKeyword: @"ALL"])
    {
      modifier = NSAllPredicateModifier;
    }
  else if ([self scanPredicateKeyword: @"NONE"])
    {
      modifier = NSAnyPredicateModifier;
      negate = YES;
    }
  else if ([self scanPredicateKeyword: @"SOME"])
    {
      modifier = NSAllPredicateModifier;
      negate = YES;
    }

  left = [self parseBinaryExpression];
  if ([self scanString: @"<" intoString: NULL])
    {
      type = NSLessThanPredicateOperatorType;
    }
  else if ([self scanString: @"<=" intoString: NULL])
    {
      type = NSLessThanOrEqualToPredicateOperatorType;
    }
  else if ([self scanString: @">" intoString: NULL])
    {
      type = NSGreaterThanPredicateOperatorType;
    }
  else if ([self scanString: @">=" intoString: NULL])
    {
      type = NSGreaterThanOrEqualToPredicateOperatorType;
    }
  else if ([self scanString: @"=" intoString: NULL])
    {
      type = NSEqualToPredicateOperatorType;
    }
  else if ([self scanString: @"!=" intoString: NULL])
    {
      type = NSNotEqualToPredicateOperatorType;
    }
  else if ([self scanPredicateKeyword: @"MATCHES"])
    {
      type = NSMatchesPredicateOperatorType;
    }
  else if ([self scanPredicateKeyword: @"LIKE"])
    {
      type = NSLikePredicateOperatorType;
    }
  else if ([self scanPredicateKeyword: @"BEGINSWITH"])
    {
      type = NSBeginsWithPredicateOperatorType;
    }
  else if ([self scanPredicateKeyword: @"ENDSWITH"])
    {
      type = NSEndsWithPredicateOperatorType;
    }
  else if ([self scanPredicateKeyword: @"IN"])
    {
      type = NSInPredicateOperatorType;
    }
  else
    {
      [NSException raise: NSInvalidArgumentException 
		   format: @"Invalid comparison predicate: %@", 
		   [[self string] substringFromIndex: [self scanLocation]]];
    }
 
  if ([self scanString: @"[cd]" intoString: NULL])
    {
      opts = NSCaseInsensitivePredicateOption
	| NSDiacriticInsensitivePredicateOption;
    }
  else if ([self scanString: @"[c]" intoString: NULL])
    {
      opts = NSCaseInsensitivePredicateOption;
    }
  else if ([self scanString: @"[d]" intoString: NULL])
    {
      opts = NSDiacriticInsensitivePredicateOption;
    }

  p = [NSComparisonPredicate predicateWithLeftExpression: left 
    rightExpression: [self parseBinaryExpression]
    modifier: modifier 
    type: type 
    options: opts];

  return negate ? [NSCompoundPredicate notPredicateWithSubpredicate: p] : p;
}

- (NSExpression *) parseExpression
{
  static NSCharacterSet *_identifier;
  NSString *ident;
  double dbl;

  if ([self scanDouble: &dbl])
    {
      return [NSExpression expressionForConstantValue: 
			       [NSNumber numberWithDouble: dbl]];
    }

  // FIXME: handle integer, hex constants, 0x 0o 0b
  if ([self scanString: @"-" intoString: NULL])
    {
      return [NSExpression expressionForFunction: @"_chs" 
        arguments: [NSArray arrayWithObject: [self parseExpression]]];
    }

  if ([self scanString: @"(" intoString: NULL])
    {
      NSExpression *arg = [self parseExpression];
      
      if (![self scanString: @")" intoString: NULL])
        {
	  [NSException raise: NSInvalidArgumentException 
		      format: @"Missing ) in expression"];
	}
      return arg;
    }

  if ([self scanString: @"{" intoString: NULL])
    {
      NSMutableArray *a = [NSMutableArray arrayWithCapacity: 10];

      if ([self scanString: @"}" intoString: NULL])
        {
	  // empty
	  // FIXME
	  return nil;
	}
      // first element
      [a addObject: [self parseExpression]];
      while ([self scanString: @"," intoString: NULL])
        {
	  // more elements
	  [a addObject: [self parseExpression]];
	}

      if (![self scanString: @"}" intoString: NULL])
        {
	  [NSException raise: NSInvalidArgumentException 
		      format: @"Missing } in aggregate"];
	}
      // FIXME
      return nil;
    }

  if ([self scanPredicateKeyword: @"NULL"])
    {
      return [NSExpression expressionForConstantValue: [NSNull null]];
    }
  if ([self scanPredicateKeyword: @"TRUE"])
    {
      return [NSExpression expressionForConstantValue: 
	[NSNumber numberWithBool: YES]];
    }
  if ([self scanPredicateKeyword: @"FALSE"])
    {
      return [NSExpression expressionForConstantValue: 
	[NSNumber numberWithBool: NO]];
    }
  if ([self scanPredicateKeyword: @"SELF"])
    {
      return [NSExpression expressionForEvaluatedObject];
    }
  if ([self scanString: @"$" intoString: NULL])
    {
      // variable
      NSExpression *var = [self parseExpression];

      if (![var keyPath])
        {
	  [NSException raise: NSInvalidArgumentException 
		      format: @"Invalid variable identifier: %@", var];
	}
      return [NSExpression expressionForVariable:[var keyPath]];
    }
	
  if ([self scanPredicateKeyword: @"%K"])
    {
      return [NSExpression expressionForKeyPath: [self nextArg]];
    }

  if ([self scanPredicateKeyword: @"%@"])
    {
      return [NSExpression expressionForConstantValue: [self nextArg]];
    }
	
  // FIXME: other formats
  if ([self scanString: @"\"" intoString: NULL])
    {
      NSString *str = @"string constant";
	
      return [NSExpression expressionForConstantValue: str];
    }
	
  if ([self scanString: @"'" intoString: NULL])
    {
      NSString *str = @"string constant";

      return [NSExpression expressionForConstantValue: str];
    }

  if ([self scanString: @"@" intoString: NULL])
    {
      NSExpression *e = [self parseExpression];

      if (![e keyPath])
        {
	  [NSException raise: NSInvalidArgumentException 
		      format: @"Invalid keypath identifier: %@", e];
	}

      // prefix with keypath
      return [NSExpression expressionForKeyPath: 
	[NSString stringWithFormat: @"@%@", [e keyPath]]];
    }

  // skip # as prefix (reserved words)
  [self scanString: @"#" intoString: NULL];
  if (!_identifier)
    {
      _identifier = [NSCharacterSet characterSetWithCharactersInString: 
	 @"_$abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"];
      RETAIN(_identifier);
    }

  if (![self scanCharactersFromSet: _identifier intoString: &ident])
    {
      [NSException raise: NSInvalidArgumentException 
		  format: @"Missing identifier: %@", 
		   [[self string] substringFromIndex: [self scanLocation]]];
    }

  return [NSExpression expressionForKeyPath: ident];
}

- (NSExpression *) parseFunctionalExpression
{
  NSExpression *left = [self parseExpression];
    
  while (YES)
    {
      if ([self scanString: @"(" intoString: NULL])
        { 
          // function - this parser allows for (max)(a, b, c) to be properly 
	  // recognized and even (%K)(a, b, c) if %K evaluates to "max"
	  NSMutableArray *args = [NSMutableArray arrayWithCapacity: 5];

	  if (![left keyPath])
	    {
	      [NSException raise: NSInvalidArgumentException 
			  format: @"Invalid function identifier: %@", left];
	    }

	  if (![self scanString: @")" intoString: NULL])
	    {
	      // any arguments
	      // first argument
	      [args addObject: [self parseExpression]];
	      while ([self scanString: @"," intoString: NULL])
	        {
		  // more arguments
		  [args addObject: [self parseExpression]];
		}

	      if (![self scanString: @")" intoString: NULL])
	        {
		  [NSException raise: NSInvalidArgumentException 
			      format: @"Missing ) in function arguments"];
		}
	    }
	  left = [NSExpression expressionForFunction: [left keyPath] 
					   arguments: args];
	}
      else if ([self scanString: @"[" intoString: NULL])
        {
	  // index expression
	  if ([self scanPredicateKeyword: @"FIRST"])
	    {
	      left = [NSExpression expressionForFunction: @"_first" 
		arguments: [NSArray arrayWithObject: [self parseExpression]]];
	    }
	  else if ([self scanPredicateKeyword: @"LAST"])
	    {
	      left = [NSExpression expressionForFunction: @"_last" 
		arguments: [NSArray arrayWithObject: [self parseExpression]]];
	    }
	  else if ([self scanPredicateKeyword: @"SIZE"])
	    {
	      left = [NSExpression expressionForFunction: @"count" 
	        arguments: [NSArray arrayWithObject: [self parseExpression]]];
	    }
	  else
	    {
	      left = [NSExpression expressionForFunction: @"_index" 
		arguments: [NSArray arrayWithObjects: left,
		[self parseExpression], nil]];
	    }
	  if (![self scanString: @"]" intoString: NULL])
	    {   
	      [NSException raise: NSInvalidArgumentException 
			  format: @"Missing ] in index argument"];
	    }
	}
      else if ([self scanString: @"." intoString: NULL])
        {
	  // keypath - this parser allows for (a).(b.c)
	  // to be properly recognized
	  // and even %K.((%K)) if the first %K evaluates to "a" and the 
	  // second %K to "b.c"
	  NSExpression *right;
		
	  if (![left keyPath])
	    {
	      [NSException raise: NSInvalidArgumentException 
			  format: @"Invalid left keypath: %@", left];
	    }
	  right = [self parseExpression];
	  if (![right keyPath])
	    {
	      [NSException raise: NSInvalidArgumentException 
			  format: @"Invalid right keypath: %@", left];
	    }

	  // concatenate
	  left = [NSExpression expressionForKeyPath:
	    [NSString stringWithFormat: @"%@.%@",
	    [left keyPath], [right keyPath]]];
	}
      else
        {
	  // done with suffixes
	  return left;
	}
    }
}

- (NSExpression *) parsePowerExpression
{
  NSExpression *left = [self parseFunctionalExpression];
  
  while (YES)
    {
      NSExpression *right;
	
      if ([self scanString: @"**" intoString: NULL])
        {
	  right = [self parseFunctionalExpression];
          // FIXME
	}
      else
        {
	  return left;
	}
    }
}

- (NSExpression *) parseMultiplicationExpression
{
  NSExpression *left = [self parsePowerExpression];
	
  while (YES)
    {
      NSExpression *right;
	
      if ([self scanString: @"*" intoString: NULL])
        {
	  right = [self parsePowerExpression];
          // FIXME
	}
      else if ([self scanString: @"/" intoString: NULL])
        {
	  right = [self parsePowerExpression];
          // FIXME
	}
      else
        {
	  return left;
	}
    }
}

- (NSExpression *) parseAdditionExpression
{
  NSExpression *left = [self parseMultiplicationExpression];
  
  while (YES)
    {
      NSExpression *right;
	
      if ([self scanString: @"+" intoString: NULL])
        {
	  right = [self parseMultiplicationExpression];
          // FIXME
	}
      else if ([self scanString: @"-" intoString: NULL])
        {
	  right = [self parseMultiplicationExpression];
          // FIXME
	}
      else
        {
	  return left;
	}
    }
}

- (NSExpression *) parseBinaryExpression
{
  NSExpression *left = [self parseAdditionExpression];
  
  while (YES)
    {
      NSExpression *right;

      if ([self scanString: @":=" intoString: NULL])	// assignment
        {
	  // check left to be a variable?
	  right = [self parseAdditionExpression];
	}
      else
	{
	  return left;
	}
    }
}


@end


/** Implementation for GSURITemplate

   Copyright (C) 2000,2001 Free Software Foundation, Inc.

   Written by: Richard Frith-Macdonald <rfm@gnu.org>
   Date: November 2025

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

   Many thanks to CSURITemplate for design inspiration, testcases, and the 
   text copied verbatim for NSError description and failure reasons.
*/

#import "common.h"

#import "Foundation/NSEnumerator.h"
#import "GNUstepBase/GSURITemplate.h"

/* Constants for NSError results.
 */
GS_DECLARE NSString *const GSURITemplateDomain = @"org.gnustep.GSURITemplate";
GS_DECLARE NSString *const GSURITemplateScanLocationKey = @"scanLocation";

/* Cached character sets for scanning patterns.
 */
static NSCharacterSet	*bracesSet = nil;
static NSCharacterSet	*digitsSet = nil;
static NSCharacterSet	*emptySet = nil;
static NSCharacterSet	*modStartSet = nil;
static NSCharacterSet	*nonZeroSet = nil;
static NSCharacterSet	*operatorSet = nil;
static NSCharacterSet	*reservedSet = nil;
static NSCharacterSet	*unreservedSet = nil;
static NSCharacterSet	*varcharSet = nil;

/* Declarations for callbacks to build results by enumerating
 */
typedef enum {
  Array,
  Query,
  Param,
} FieldStyle;

typedef struct {
  FieldStyle	style;
  NSString	*start;
  id		result;
} FieldContext;

static void addField(FieldContext *ctx, NSString *key, NSString *value);

typedef	void (*addFieldCallback)(FieldContext*, NSString*, NSString*);

static void
addField(FieldContext *ctx, NSString *key, NSString *value)
{
  switch (ctx->style)
    {
      case Array:
	/* We are creating an array of key=value strings
	 */
	{
	  NSMutableArray	*a = (NSMutableArray*)ctx->result;

	  [a addObject: [NSString stringWithFormat: @"%@=%@", key, value]];
	}
	break;

      case Query:
	/* We are adding field definitions to a query string.
	 */
	{
	  NSMutableString	*m = (NSMutableString*)ctx->result;

	  if (ctx->start)
	    {
	      [m appendString: ctx->start];
	      ctx->start = nil;
	    }
	  else
	    {
	      [m appendString: @"&"];
	    }
	  
	  [m appendString: key];
	  [m appendString: @"="];
	  [m appendString: value];
	}
	break;

      case Param:
	/* We are adding parameters
	 */
	{
	  NSMutableString	*m = (NSMutableString*)ctx->result;

	  [m appendString: @";"];
	  [m appendString: key];
	  if (NO == [value isEqualToString: @""])
	    {
	      [m appendString: @"="];
	      [m appendString: value];
	    }
	  }
	break;
    }
}

/* Function to create a template error object
 */
static NSError *
mkError(GSURITemplateError code, NSString *desc, NSString *reason)
{
  NSDictionary	*userInfo;
  
  userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
    desc, NSLocalizedDescriptionKey,
    reason, NSLocalizedFailureReasonErrorKey,
    nil];

  return [NSError errorWithDomain: GSURITemplateDomain
			     code: code
			 userInfo: userInfo];
}

/* Function to add a scan location to a template error object
 */
static NSError *
modError(NSError *e, int pos)
{
  NSMutableDictionary	*m = AUTORELEASE([[e userInfo] mutableCopy]);

  if (m)
    {
      [m setObject: [NSNumber numberWithInteger: pos]
	    forKey: GSURITemplateScanLocationKey];
      e = [NSError errorWithDomain: GSURITemplateDomain
			      code: [e code]
			  userInfo: m];
    }
  return e;
}

/* Methods for percent encoding values to appear in a URL
 */
@interface NSObject (URITemplate)
- (NSString*) gsUriString;
- (NSString*) gsUriStringEscaped: (BOOL)reserved;
- (NSArray*) gsUriExplodedItems;
- (NSArray*) gsUriExplodedItemsEscaped: (BOOL)reserved;
- (void) gsUriEnumerateExplodedItemsEscaped: (BOOL)reserved
				 defaultKey: (NSString*)key
				   callback: (addFieldCallback)cb
				    context: (FieldContext*)ctx;
@end

/* Declare the base classes implementing terms of an expression
 */

@interface GSUTTerm : NSObject
{
  id	termObject;
}
+ (id) termWithValue: (id)theValue;
- (NSString*) infix;
- (BOOL) permitReserved;
- (NSString*) prepend;
@end

@interface GSUTInfixExprTerm : GSUTTerm
@end

@interface GSUTPrependExprTerm : GSUTTerm
@end

@interface GSUTQueryExprTerm : GSUTTerm
{
  BOOL	isFirst;
}
- (NSString*) prepend;
@end

/* Other term classes (in alphabetical order) which inherit from the base ones.
 */
@interface GSUTCommaExprTerm : GSUTInfixExprTerm
@end

@interface GSUTDotExprTerm : GSUTPrependExprTerm
@end

@interface GSUTHashExprTerm : GSUTCommaExprTerm
@end

@interface GSUTLiteralTerm : GSUTTerm
@end

@interface GSUTParameterExprTerm : GSUTTerm
@end

@interface GSUTQueryContinuationExprTerm : GSUTQueryExprTerm
@end

@interface GSUTReservedExprTerm : GSUTCommaExprTerm
@end

@interface GSUTSlashExprTerm : GSUTPrependExprTerm
@end

/* The base class for a variable represents the unexpanded version.
 */
@interface GSUTVariable : NSObject
{
  NSString	*key;
}
+ (id) variableWithKey: (NSString*)aKey;
- (NSArray *) valuesWithVariables: (NSDictionary*)variables
		   permitReserved: (BOOL)reserved
			    error: (NSError**)error;
- (BOOL) enumerateKeyValuesWithVariables: (NSDictionary*)variables
			  permitReserved: (BOOL)reserved
				callback: (addFieldCallback)cb
				 context: (FieldContext*)ctx
                                   error: (NSError**)error;
@end

/* This class represents the exploded version of a variable.
 */
@interface GSUTExplodedVariable : GSUTVariable
@end

@interface GSUTPrefixedVariable : GSUTVariable
{
  NSUInteger	maxLength;
}
+ (id) variableWithKey: (NSString*)aKey maxLength: (NSUInteger)aMaxLength;
@end



/****************************************************************
 * Categories providing (optionally escaped) string values.	*
 ****************************************************************/

@implementation NSArray (URITemplate)

- (NSString *) gsUriString
{
  NSMutableArray	*result = [NSMutableArray array];

  GS_FOR_IN(id, item, self)
    {
      [result addObject: [item gsUriString]];
    }
  GS_END_FOR(self)
  return [result componentsJoinedByString: @","];
}

- (NSString*) gsUriStringEscaped: (BOOL)reserved
{
  NSMutableArray	*result = [NSMutableArray array];

  GS_FOR_IN(id, item, self)
    {
      [result addObject: [item gsUriStringEscaped: reserved]];
    }
  GS_END_FOR(self)
  return [result componentsJoinedByString: @","];
}

- (NSArray*) gsUriExplodedItems
{
  return self;
}
@end


@implementation NSDictionary (URITemplate)

- (NSString *) gsUriString
{
  NSMutableArray	*result = [NSMutableArray array];

  GS_FOR_IN(id, key, self)
    {
      id	val = [self objectForKey: key];

      [result addObject: [key gsUriString]];
      [result addObject: [val gsUriString]];
    }
  GS_END_FOR(self)
  return [result componentsJoinedByString: @","];
}

- (NSString *) gsUriStringEscaped: (BOOL)reserved
{
  NSMutableArray	*result = [NSMutableArray array];

  GS_FOR_IN(id, key, self)
    {
      id	val = [self objectForKey: key];

      [result addObject: [key gsUriStringEscaped: reserved]];
      [result addObject: [val gsUriStringEscaped: reserved]];
    }
  GS_END_FOR(self)
  return [result componentsJoinedByString: @","];
}

- (NSArray *) gsUriExplodedItems
{
  NSMutableArray	*result = [NSMutableArray array];

  GS_FOR_IN(id, key, self)
    {
      id	val = [self objectForKey: key];

      [result addObject: key];
      [result addObject: val];
    }
  GS_END_FOR(self)
  return [NSArray arrayWithArray: result];
}

- (NSArray *) gsUriExplodedItemsEscaped: (BOOL)reserved
{
  FieldContext	context;

  context.style = Array;
  context.start = nil;
  context.result = [NSMutableArray array];

  [self gsUriEnumerateExplodedItemsEscaped: reserved
					    defaultKey: nil
					      callback: addField
					       context: &context];
  return (NSMutableArray*)context.result;
}

- (void) gsUriEnumerateExplodedItemsEscaped: (BOOL)reserved
				 defaultKey: (NSString*)key
				   callback: (addFieldCallback)cb
				    context: (FieldContext*)ctx
{
  GS_FOR_IN(NSString*, k, self)
    {
      NSString	*v = [self objectForKey: k];

      k = [k gsUriStringEscaped: reserved];
      v = [v gsUriStringEscaped: reserved];
      cb(ctx, k, v);
    }
  GS_END_FOR(self)
}
@end

@implementation NSNull (URITemplateDescriptions)

- (NSArray*) gsUriExplodedItems
{
  return [NSArray array];
}
@end


@implementation NSObject (URITemplate)

- (NSString*) gsUriString
{
  return [self description];
}

- (NSString*) gsUriStringEscaped: (BOOL)reserved;
{
  NSString	*s = [self gsUriString];

  return [s gsUriStringEscaped: reserved];
}

- (NSArray*) gsUriExplodedItems
{
  return [NSArray arrayWithObject: self];
}

- (NSArray*) gsUriExplodedItemsEscaped: (BOOL)reserved
{
  NSMutableArray *result = [NSMutableArray array];
  NSArray	*exploded = [self gsUriExplodedItems];

  GS_FOR_IN(id, value, exploded)
    {
      [result addObject: [value gsUriStringEscaped: reserved]];
    }
  GS_END_FOR(exploded)
  return [NSArray arrayWithArray: result];
}

- (void) gsUriEnumerateExplodedItemsEscaped: (BOOL)reserved
				 defaultKey: (NSString*)key
				   callback: (addFieldCallback)cb
				    context: (FieldContext*)ctx
{
  NSArray	*exploded = [self gsUriExplodedItemsEscaped: reserved];

  GS_FOR_IN(NSString*, value, exploded)
    {
      cb(ctx, key, value);
    }
  GS_END_FOR(exploded)
}
@end


@implementation NSString (URITemplate)

- (NSString*) gsUriString
{
  return self;
}

- (NSString*) gsUriStringEscaped: (BOOL)reserved
{
  if (reserved)
    {
      return [self stringByAddingPercentEncodingWithAllowedCharacters:
	reservedSet];
    }
  else
    {
      return [self stringByAddingPercentEncodingWithAllowedCharacters:
	unreservedSet];
    }
}
@end



/****************************************************************
 * Classes representing terms in a template expression.		*
 ****************************************************************/

@implementation GSUTCommaExprTerm

- (NSString*) infix
{
  return @",";
}
@end


@implementation GSUTDotExprTerm

- (NSString*) prepend
{
  return @".";
}
@end


@implementation GSUTHashExprTerm

- (BOOL) permitReserved
{
  return YES;
}

- (NSString*) prepend
{
  return @"#";
}
@end


@implementation GSUTInfixExprTerm

- (NSString*) expandWithVariables: (NSDictionary*)variables
			    error: (NSError**)error
{
  BOOL 			isFirst = YES;
  NSMutableString	*result = [NSMutableString string];

  GS_FOR_IN(GSUTVariable*, variable, termObject)
    {
      NSArray	*values = [variable valuesWithVariables: variables
					 permitReserved: [self permitReserved]
						  error: error];
      if (nil == values)
	{
	  return nil;	// Error expanding the variable.
	}
      
      GS_FOR_IN(NSString*, value, values)
	{
	  if (isFirst)
	    {
	      isFirst = NO;
	      [result appendString: [self prepend]];
	    }
	  else
	    {
	      [result appendString: [self infix]];
	    }
	  [result appendString: value];
	}
      GS_END_FOR(values)
    }
  GS_END_FOR(termObject)
  
  return result;
}

- (NSString*) infix
{
  return @"";
}

- (BOOL) permitReserved
{
  return NO;
}

- (NSString*) prepend
{
  return @"";
}
@end


@implementation GSUTLiteralTerm
- (NSString*) expandWithVariables: (NSDictionary*)variables
			    error: (NSError**)error
{
  return termObject;
}
@end


@implementation GSUTParameterExprTerm

- (NSString*) expandWithVariables: (NSDictionary*)variables
			    error: (NSError**)error
{
  FieldContext	context;
  BOOL		reserved = [self permitReserved];

  context.style = Param;
  context.start = nil;
  context.result = [NSMutableString string];

  GS_FOR_IN(GSUTVariable*, variable, termObject)
    {
      if (NO == [variable enumerateKeyValuesWithVariables: variables
					   permitReserved: reserved
						 callback: addField
						  context: &context
						    error: error])
	{
	  return nil;
	}
    }
  GS_END_FOR(termObject)
  return (NSString*)context.result;
}

- (BOOL) permitReserved
{
  return NO;
}
@end


@implementation GSUTPrependExprTerm

- (NSString*) expandWithVariables: (NSDictionary*)variables
			    error: (NSError**)error
{
  NSMutableString	*result = [NSMutableString string];

  GS_FOR_IN(GSUTVariable*, variable, termObject)
    {
      NSArray	*array;

      array = [variable valuesWithVariables: variables
			     permitReserved: [self permitReserved]
				      error: error];
      GS_FOR_IN(NSString*, value, array)
	{
	  [result appendString: [self prepend]];
	  [result appendString: value];
        }
      GS_END_FOR(array)
    }
  GS_END_FOR(termObject)
    
  return result;
}

- (BOOL) permitReserved
{
  return NO;
}

- (NSString*) prepend
{
  return @"";
}
@end


@implementation GSUTQueryContinuationExprTerm

- (NSString*) prepend
{
  return @"&";
}
@end


@implementation GSUTQueryExprTerm

- (NSString*) expandWithVariables: (NSDictionary*)variables
			    error: (NSError**)error
{
  FieldContext	context;
  BOOL		reserved = [self permitReserved];

  context.style = Query;
  context.start = [self prepend];
  context.result = [NSMutableString string];

  GS_FOR_IN(GSUTVariable*, variable, termObject)
    {
      if (NO == [variable enumerateKeyValuesWithVariables: variables
					   permitReserved: reserved
						 callback: addField
						  context: &context
						    error: error])
	{
	  return nil;
	}
    }
  GS_END_FOR(termObject)
  return context.result;  
}

- (BOOL) permitReserved
{
  return NO;
}

- (NSString*) prepend
{
  return @"?";
}
@end

@implementation GSUTReservedExprTerm

- (BOOL) permitReserved
{
  return YES;
}
@end


@implementation GSUTSlashExprTerm

- (NSString*) prepend
{
  return @"/";
}
@end


@implementation GSUTTerm
+ (id) termWithValue: (id)theValue;
{
  GSUTTerm	*t = [self alloc];

  if ((t = [t init]) != nil)
    {
      ASSIGN(t->termObject, theValue);
    }
  return AUTORELEASE(t);
}

- (void) dealloc
{
  DESTROY(termObject);
  DEALLOC
}

- (NSString *) expandWithVariables: (NSDictionary*)variables
			     error: (NSError**)error
{
  return [self subclassResponsibility: _cmd];
}

- (NSString*) infix
{
  return nil;
}

- (BOOL) permitReserved
{
  return NO;
}

- (NSString*) prepend
{
  return nil;
}
@end



/****************************************************************
 * Classes populating values with variables for an expression.	*
 ****************************************************************/

@implementation GSUTExplodedVariable

- (NSArray*) valuesWithVariables: (NSDictionary*)variables
		  permitReserved: (BOOL)reserved
			   error: (NSError**)error
{
  NSMutableArray	*result = [NSMutableArray array];
  id			values = [variables objectForKey: key];
  NSArray		*exploded;

  if (nil == values)
    {
      return [NSArray array];
    }
  
  exploded = [values gsUriExplodedItemsEscaped: reserved];
  GS_FOR_IN(id, value, exploded)
    {
      [result addObject: value];
    }
  GS_END_FOR(exploded)
  
  return result;
}

- (BOOL) enumerateKeyValuesWithVariables: (NSDictionary *) variables
			  permitReserved: (BOOL)reserved
				callback: (addFieldCallback)cb
				 context: (FieldContext*)ctx
                                   error: (NSError**)error;
{
  id	values = [variables objectForKey: key];

  if (values)
    {
      [values gsUriEnumerateExplodedItemsEscaped: reserved
				      defaultKey: key
				        callback: cb
					 context: ctx];
    }
  return YES;
}

@end

@implementation GSUTPrefixedVariable

+ (id) variableWithKey: (NSString*)aKey
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"Failed to call designated initializer. Use '+variableWithKey:maxLength:'"];
  return nil;
}

+ (id) variableWithKey: (NSString*)aKey maxLength: (NSUInteger)aMaxLength
{
  GSUTPrefixedVariable	*v = [super variableWithKey: aKey];

  if (v)
    {
      v->maxLength = aMaxLength;
    }
  return v;
}

- (NSArray *) valuesWithVariables: (NSDictionary*)variables
		   permitReserved: (BOOL)reserved
			    error: (NSError**)error
{
  id 			value = [variables objectForKey: key];
  NSMutableArray 	*result = [NSMutableArray array];
  NSString 		*description;
    
  if (NO == [value isKindOfClass: [NSString class]])
    {
      if (error)
	{
	  *error = mkError(GSURITemplateExpansionInvalidValueError,
	    NSLocalizedString(@"An unexpandable value was given for a template variable.", nil),
	    [NSString stringWithFormat: NSLocalizedString(@"Variables with a maximum length modifier can only be expanded with string values, but a value of type '%@' given.", nil), [value class]]);
	}
      return nil;
    }
    
  if (nil == value || value == (id)[NSNull null])
    {
      return [NSArray array];
    }

  description = [value gsUriString];
  if (maxLength <= [description length])
    {
      description = [description substringToIndex: maxLength];
    }
  
  [result addObject: [description gsUriStringEscaped: reserved]];
  
  return [NSArray arrayWithArray: result];
}

- (BOOL) enumerateKeyValuesWithVariables: (NSDictionary*)variables
			  permitReserved: (BOOL)reserved
				callback: (addFieldCallback)cb
				 context: (FieldContext*)ctx
                                   error: (NSError**)error;
{
  NSArray 	*values;

  values = [self valuesWithVariables: variables
		      permitReserved: reserved
			       error: error];
  if (nil == values)
    {
      return NO;	// Error was expanding the variables.
    }
  
  GS_FOR_IN(NSString*, value, values)
    {
      cb(ctx, key, value);
    }
  GS_END_FOR(values)
  return YES;
}

@end

@implementation GSUTVariable

+ (id) variableWithKey: (NSString*)aKey
{
  GSUTVariable	*v = [self alloc];

  if ((v = [v init]) != nil)
    {
      ASSIGN(v->key, aKey);
    }
  return AUTORELEASE(v);
}

- (void) dealloc
{
  DESTROY(key);
  DEALLOC
}

- (NSArray*) valuesWithVariables: (NSDictionary*)variables
		  permitReserved: (BOOL)permitReserved
			   error: (NSError**)error
{
  NSMutableArray	*result; 
  id			value = [variables objectForKey: key];

  if (nil == value
    || value == (id)[NSNull null]
    || ([value isKindOfClass: [NSArray class]] && [value count] == 0))
    {
      return [NSArray array];
    }
    
  result = [NSMutableArray arrayWithObject:
    [value gsUriStringEscaped: permitReserved]];
    
  return [NSArray arrayWithArray: result];
}

- (BOOL) enumerateKeyValuesWithVariables: (NSDictionary*)variables
			  permitReserved: (BOOL)reserved
				callback: (addFieldCallback)cb
				 context: (FieldContext*)ctx
                                   error: (NSError**)error;
{
  NSString	*escaped;
  id		value = [variables objectForKey: key];

  if (nil == value || value == (id)[NSNull null])
    {
      return YES;
    }
  
  if ([value isEqual: [NSArray array]])
    {
      cb(ctx, key, @"");
      return YES;
    }
  
  escaped = [value gsUriStringEscaped: reserved];
  cb(ctx, key, escaped);
  return YES;
}

@end



/* Forward declaration of internal method so that public methods can
 * use them.
 */
@interface GSURITemplate (Internal)
- (id) _initWithPattern: (NSString*)aPattern;
- (BOOL) _parse: (NSError**)error;
- (id) _termWithExpression: (NSString*)expression error: (NSError**)error;
- (id) _variableWithVarspec: (NSString*)varspec error: (NSError**)error;
- (NSArray*) _variablesWithVarspecs: (NSString*)specs error: (NSError**)error;
@end


/****************************************************************
 * The template class itself. This provides the public API.	*
 ****************************************************************/

@implementation GSURITemplate

+ (void) initialize
{
  if (nil == bracesSet)
    {
      NSMutableCharacterSet	*m;

      bracesSet = RETAIN([NSCharacterSet
	characterSetWithCharactersInString: @"{}"]);
      emptySet = RETAIN([NSCharacterSet
	characterSetWithCharactersInString: @""]);
      nonZeroSet = RETAIN([NSCharacterSet
	characterSetWithCharactersInString: @"123456789"]);
      digitsSet = RETAIN([NSCharacterSet decimalDigitCharacterSet]);
      modStartSet = RETAIN([NSCharacterSet
	characterSetWithCharactersInString: @":*"]);
      operatorSet = RETAIN([NSCharacterSet
	characterSetWithCharactersInString: @"+#./;?&=,!@|"]);
      /* Characters allowed in normal expansion.
       */
      unreservedSet = RETAIN([NSCharacterSet characterSetWithCharactersInString:
	@"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._~"]);
      /* Characters alloed in reserved/fragment expansion.
       */
      reservedSet = RETAIN([NSCharacterSet characterSetWithCharactersInString:
	@"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._~"
	@"%:/?#[]@!$&'()*+,;="]);
      m = [NSMutableCharacterSet alphanumericCharacterSet];
      [m addCharactersInString: @"._%"];
      varcharSet = RETAIN(m);
    }
}

+ (instancetype) templateWithString: (NSString*)aPattern
			      error: (NSError**)error
{
  GSURITemplate	*t = [self alloc];

  if ((t = [t _initWithPattern: aPattern]) != nil)
    {
      if (NO == [t _parse: error])
	{
	  DESTROY(t);
	}
    }
  return AUTORELEASE(t);
}

- (void) dealloc
{
  DESTROY(pattern);
  DESTROY(terms);
  DESTROY(base);
  DEALLOC
}

- (id) init
{
  DESTROY(self);
  [NSException raise: NSInternalInconsistencyException
	      format: @"Failed to call designated initializer. Use '+templateWithString:relativeToURL:error:'"];
  return nil;
}

- (NSString*) pattern
{
  return pattern;
}

- (NSString*) relativeStringWithVariables: (NSDictionary*)variables
				    error: (NSError**)error
{
  NSError		*expansionError = nil;
  NSMutableString	*result = [NSMutableString string];
  BOOL			errorEncountered = NO;

  if (nil == variables)
    {
      expansionError = mkError(GSURITemplateExpansionNoVariablesError,
	NSLocalizedString(@"A template cannot be expanded without a dictionary of variables.", nil),
	NSLocalizedString(@"The variables dictionary passed to the method was empty.", nil));
      if (error) *error = expansionError;
      return nil;
    }
  GS_FOR_IN(GSUTTerm*, term, terms)
    {
      NSString	*value;

      value = [term expandWithVariables: variables error: &expansionError];
      if (nil == value)
	{
	  // An error was encountered expanding the term.
	  errorEncountered = YES;
	  break;
        }
      [result appendString: value];
    }
  GS_END_FOR(terms)
  if (expansionError && error)
    {
      *error = expansionError;
    }
  return errorEncountered ? nil : result;
}

- (NSURL*) URLWithVariables: (NSDictionary*)variables
	      relativeToURL: (NSURL*)baseURL
		      error: (NSError**)error
{
  NSString	*expanded;
  NSURL		*result = nil;

  expanded = [self relativeStringWithVariables: variables error: error];
  if (expanded)
    {
      if (nil == baseURL)
	{
	  baseURL = base;	// Use the base we were initialised with
	}
      result = [NSURL URLWithString: expanded relativeToURL: baseURL];
    }
  return result;
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"<%@:%p pattern=\"%@\">",
    NSStringFromClass([self class]), self, pattern];
}
@end



/****************************************************************
 * Category for initialisation including parsing of pattern.    *
 ****************************************************************/

@implementation GSURITemplate (Internal)
- (id) _initWithPattern: (NSString*)aPattern
{
  if (nil != (self = [super init]))
    {
      ASSIGNCOPY(pattern, aPattern);
      terms = [NSMutableArray new];
    }
  return self;
}

- (BOOL) _parse: (NSError**)error
{
  NSError	*e;
  NSRange	range;
  NSScanner 	*scanner;
  NSString	*relativeString;

  if (NULL == error)
    {
      error = &e;
    }
  *error = nil;

  /* If the pattern is that of an absolute URI, separate the base from
   * the relatve string.
   */
  relativeString = pattern;
  if ((range = [pattern rangeOfString: @"://"]).length > 0)
    {
      NSUInteger	position = NSMaxRange(range);
      NSURL		*u = nil;

      range = NSMakeRange(position, [pattern length] - position);
      range = [pattern rangeOfString: @"/" options: 0 range: range];
      if (range.length > 0)
	{
	  u = [NSURL URLWithString: [pattern substringToIndex: range.location]];
	  relativeString = [pattern substringFromIndex: range.location];
	}
      if (nil == u)
	{
	  *error = mkError(GSURITemplateFormatAbsolutePartError,
	    NSLocalizedString(@"The absolute URI part is present but invalid.", nil),
	    NSLocalizedString(@"The '://' part of the URI template was found but the absolute part could not be parsed by NSURL.", nil));
	  *error = modError(*error, (position - 3));
	  return NO;
	}
      ASSIGN(base, u);
    }

  scanner = [NSScanner scannerWithString: relativeString];
  [scanner setCharactersToBeSkipped: emptySet];

  while (NO == [scanner isAtEnd])
    {
      NSString *curlyBracket = nil;
      NSString *expression = nil;
      NSString *literal = nil;

      if ([scanner scanUpToCharactersFromSet: bracesSet
				  intoString: &literal])
	{
	  [terms addObject:
	    [GSUTLiteralTerm termWithValue: literal]];
	}
      
      [scanner scanCharactersFromSet: bracesSet intoString: &curlyBracket];
      if ([curlyBracket isEqualToString: @"}"])
	{
	  *error = mkError(GSURITemplateFormatCloseWithoutOpenError,
	    NSLocalizedString(@"An expression was closed that was never opened.", nil),
	    NSLocalizedString(@"A closing '}' character was encountered that was not preceeded by an opening '{' character.", nil));
	  *error = modError(*error, [scanner scanLocation]);
	  break;
	}
      
      if ([scanner scanUpToString: @"}" intoString: &expression])
	{
	  id	term;

	  if (NO == [scanner scanString: @"}" intoString: NULL])
	    {
	      *error = mkError(GSURITemplateFormatOpenWithoutCloseError,
		NSLocalizedString(@"An expression was opened but never closed.", nil),
		NSLocalizedString(@"An opening '{' character was not terminated by a '}' character.", nil));
	      *error = modError(*error, [scanner scanLocation]);
	      break;
	    }
	  
	  term = [self _termWithExpression: expression error: error];
	  if (!term)
	    {
	      *error = modError(*error, [scanner scanLocation]);
	      break;
	    }
	  
	  [terms addObject: term];
	}
    }
  
  return *error ? NO : YES;
}

- (id) _termWithExpression: (NSString*)expression error: (NSError**)error
{
  NSString 	*operator = nil;
  NSArray	*variables;
  NSScanner	*scanner;
  NSString	*specs;

  scanner = [NSScanner scannerWithString: expression];
  [scanner setCharactersToBeSkipped: emptySet];

  [scanner scanCharactersFromSet: operatorSet intoString: &operator];
  specs = [expression substringFromIndex: [scanner scanLocation]];
  if ([operator length] > 1)
    {
      if (error)
	{
	  *error = mkError(GSURITemplateFormatOperatorError,
	    NSLocalizedString(@"An invalid operator was encountered.", nil),
	    [NSString stringWithFormat: NSLocalizedString(@"An operator was encountered with a length greater than 1 character ('%@').", nil), operator]);
	}
      return nil;
    }
  
  variables = [self _variablesWithVarspecs: specs error: error];
  if (nil == variables)
    {
      return nil;
    }
  
  if ([operator length] == 0)
    {
      operator = @",";
    }
  switch ([operator characterAtIndex: 0])
    {
      case ',': return [GSUTCommaExprTerm termWithValue: variables];
      case '.': return [GSUTDotExprTerm termWithValue: variables];
      case '#': return [GSUTHashExprTerm termWithValue: variables];
      case ';': return [GSUTParameterExprTerm termWithValue: variables];
      case '&': return [GSUTQueryContinuationExprTerm termWithValue: variables];
      case '?': return [GSUTQueryExprTerm termWithValue: variables];
      case '+': return [GSUTReservedExprTerm termWithValue: variables];
      case '/': return [GSUTSlashExprTerm termWithValue: variables];
      default:
      // The operator is unknown or reserved.
      if (error)
	{
	  *error = mkError(GSURITemplateFormatOperatorError,
	    NSLocalizedString(@"An invalid operator was encountered.", nil),
	    [NSString stringWithFormat: NSLocalizedString(@"The URI template specification does not include an operator for the character '%@'.", nil), operator]);
	}
      return nil;
    }
}

/* See section 2.3 of the RFC for varspec details.
 */
- (id) _variableWithVarspec: (NSString*)varspec error: (NSError**)error
{
  NSScanner	*scanner;
  NSString	*key;
  NSString	*modifierStart;

  NSParameterAssert(varspec);
  NSParameterAssert(error);
  if ([varspec rangeOfString: @"$"].location != NSNotFound)
    {
      *error = mkError(GSURITemplateFormatVariableKeyError,
	NSLocalizedString(@"The template contains an invalid variable key.", nil),
	NSLocalizedString(@"A variable key containing the forbidden character '$' was encountered.", nil));
      return nil;
    }
			      
  scanner = [NSScanner scannerWithString: varspec];
  [scanner setCharactersToBeSkipped: emptySet];
  key = nil;
  [scanner scanCharactersFromSet: varcharSet intoString: &key];
  
  modifierStart = nil;
  [scanner scanCharactersFromSet: modStartSet intoString: &modifierStart];
  
  if ([modifierStart isEqualToString: @"*"])		// Explode
    {
      if (NO == [scanner isAtEnd])
	{
	  // There were extra characters after the explode modifier.
	  *error = mkError(GSURITemplateFormatVariableModifierError,
	    NSLocalizedString(@"The template contains an invalid variable modifier.", nil),
	    [NSString stringWithFormat: NSLocalizedString(@"Extra characters were found after the explode modifier ('*') for the variable '%@'.", nil), key]);
	  return nil;
	}
      
      return [GSUTExplodedVariable variableWithKey: key];
    }
  else if ([modifierStart isEqualToString: @":"])	// Prefix
    {
      NSString	*firstDigit = @"";
      NSString	*moreDigits;
      NSString	*allDigits;
      NSUInteger maxLength;

      if (NO == [scanner scanCharactersFromSet: nonZeroSet
				    intoString: &firstDigit])
	{
	  *error = mkError(GSURITemplateFormatVariableModifierError,
	    NSLocalizedString(@"The template contains an invalid variable modifier.", nil),
	    [NSString stringWithFormat: NSLocalizedString(@"The variable '%@' was followed by the maximum length modifier (':'), but the maximum length argument was prefixed with an invalid character.", nil), key]);
	  return nil;
	}
      moreDigits = @"";
      [scanner scanCharactersFromSet: digitsSet intoString: &moreDigits];
      allDigits = [firstDigit stringByAppendingString: moreDigits];
      
      if (NO == [scanner isAtEnd])
	{
	  *error = mkError(GSURITemplateFormatVariableModifierError,
	    NSLocalizedString(@"The template contains an invalid variable modifier.", nil),
	    [NSString stringWithFormat: NSLocalizedString(@"The variable '%@' was followed by the maximum length modifier (':'), but the maximum length argument is not numeric.", nil), key]);
	  return nil;
	}

      maxLength = [allDigits integerValue];
      return [GSUTPrefixedVariable variableWithKey: key maxLength: maxLength];
    }
  else
    {
      if (NO == [scanner isAtEnd])
	{
	  *error = mkError(GSURITemplateFormatVariableKeyError,
	    NSLocalizedString(@"The template contains an invalid variable key.", nil),
	    [NSString stringWithFormat: NSLocalizedString(@"The variable key '%@' is invalid.", nil), varspec]);
	  return nil;
	}
      return [GSUTVariable variableWithKey: key];
    }
  
  return nil;
}

- (NSArray*) _variablesWithVarspecs: (NSString*)specs error: (NSError**)error
{
  NSMutableArray	*variables;
  NSScanner		*scanner; 

  NSParameterAssert(specs);
  NSParameterAssert(error);

  variables = [NSMutableArray array];
  scanner = [NSScanner scannerWithString: specs];
  [scanner setCharactersToBeSkipped: emptySet];

  while (NO == [scanner isAtEnd])
    {
      id	variable;
      NSString	*varspec = nil;

      [scanner scanUpToString: @"," intoString: &varspec];
      [scanner scanString: @"," intoString: NULL];
      variable = [self _variableWithVarspec: varspec error: error];
      if (nil == variable)
	{
	  return nil;	// Error parsing varspec.
	}
      [variables addObject: variable];
    }
  return variables;
}

@end

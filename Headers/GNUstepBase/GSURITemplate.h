/** Interface for URI template class

   Copyright (C) 2025 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald  <rfm@gnu.org>

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

   AutogsdocSource: Additions/GSURITemplate.m
*/

#ifndef __GSURITemplate_h_GNUSTEP_BASE_INCLUDE
#define __GSURITemplate_h_GNUSTEP_BASE_INCLUDE

#import <GNUstepBase/GSVersionMacros.h>

#if     OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

#import <Foundation/Foundation.h>

#if     defined(__cplusplus)
extern "C" {
#endif

/** The domain of errors returned by `GSURITemplate` objects.
 */
GS_EXPORT NSString * const GSURITemplateErrorDomain;

typedef NS_ENUM(NSInteger, GSURITemplateError)
{
  // Errors in the template pattern syntax
  GSURITemplateFormatAbsolutePartError = 1,
  GSURITemplateFormatCloseWithoutOpenError,
  GSURITemplateFormatOpenWithoutCloseError,
  GSURITemplateFormatOperatorError,
  GSURITemplateFormatVariableKeyError,
  GSURITemplateFormatVariableModifierError,
  // Errors expanding the template pattern
  GSURITemplateExpansionInvalidValueError = 100,
  GSURITemplateExpansionNoVariablesError
};

/** For errors returned while parsing a template pattern string,
 * the is key may be used to fetch the character offset within the
 * pattern at which the error occurred from the userInfo Dictionary.
 */
GS_EXPORT NSString * const GSURITemplateScanLocationKey;

/** Class for parsing and expanding URL templates acording to the
 * RFC6570 specification (see https://tools.ietf.org/html/rfc6570).
 * 
 *  eg. 
 * 
 * template = [GSURITemplate templateWithString: @&quot;/search{?q}&quot;
 *				  relativeToURL: aURL error: &amp;error];
 */
GS_EXPORT_CLASS
@interface GSURITemplate : NSObject
{
  NSString		*pattern;
  NSMutableArray	*terms;
  NSURL			*base;
}

/** Creates and returns an instance initialized with the given pattern.<br />
 * The pattern may be either an absolute template or a relative template.
 */ 
+ (instancetype) templateWithString: (NSString*)aPattern
			      error: (NSError**)error;

/** The URI template pattern used to initialize the receiver.
 */
- (NSString*) pattern;

/** Expands the receiver with the specified variables, returning the
 * relative part of the result.<br />
 * Returns nil if the template cannot be expanded with the variables.<br />
 */ 
- (NSString*) relativeStringWithVariables: (NSDictionary*)variables
			            error: (NSError**)error;

/** Expands the template with the given variables and reurns a new URL
 * relative to the given base URL or, if that is nil, relative to the
 * absolute part of the pattern with which the template was created.<br />
 * In the absence of any absolute part, this method returns a relative URL.
 */
- (NSURL*) URLWithVariables: (NSDictionary *)variables
	      relativeToURL: (NSURL*)baseURL
		      error: (NSError**)error;

@end

#if     defined(__cplusplus)
}
#endif  

#endif  /* OS_API_VERSION(GS_API_NONE,GS_API_NONE) */

#endif /* __GSURITemplate_h_GNUSTEP_BASE_INCLUDE */

/* NSAssertionHandler - Object encapsulation of assertions
   Copyright (C) 1995, 1997 Free Software Foundation, Inc.
   
   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Apr 1995
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#include <config.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSThread.h>

@implementation NSAssertionHandler

/* Key for thread dictionary. */
static NSString *dict_key = @"_NSAssertionHandler";

+ (NSAssertionHandler*)currentHandler
{
  NSMutableDictionary *dict;
  NSAssertionHandler *handler;

  dict = GSCurrentThreadDictionary();
  handler = [dict objectForKey: dict_key];
  if (handler == nil)
    {
      handler = [[NSAssertionHandler alloc] init];
      [dict setObject: handler forKey: dict_key];
    }
  return handler;
}

- (void) handleFailureInFunction: (NSString*)functionName 
			    file: (NSString*)fileName 
		      lineNumber: (int)line 
		     description: (NSString*)format,...
{
  id message;
  va_list ap;

  va_start(ap, format);
  message =
    [NSString
      stringWithFormat: @"%@:%d  Assertion failed in %@.  %@",
      fileName, line, functionName, format];
  NSLogv(message, ap);
  va_end(ap);

  [NSException raise:NSInternalInconsistencyException
	       format: message arguments: ap];
  /* NOT REACHED */
}

- (void) handleFailureInMethod: (SEL) aSelector
                        object: object
                          file: (NSString *) fileName
                    lineNumber: (int) line
                   description: (NSString *) format,...
{
  id message;
  va_list ap;

  va_start(ap, format);
  message =
    [NSString
      stringWithFormat: @"%@:%d  Assertion failed in %s, method %s.  %@",
      fileName, line, object_get_class_name(object), sel_get_name(aSelector),
      format];
  NSLogv(message, ap);

  [NSException raise: NSInternalInconsistencyException 
	       format: message arguments: ap];
  va_end(ap);
  /* NOT REACHED */
}

@end

/* NSAssertionHandler - Object encapsulation of assertions
   Copyright (C) 1995 Free Software Foundation, Inc.
   
   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Apr 1995
   
   This file is part of the Gnustep Base Library.
   
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>

@implementation NSAssertionHandler

+ (NSAssertionHandler *)currentHandler
{
  // FIXME: current handler should come from current thread dictionary;
  static NSAssertionHandler *only_one = nil;
    
  if (!only_one)
    only_one = [NSAssertionHandler new];
  return only_one;
}

- (void)handleFailureInFunction:(NSString *)functionName 
   file:(NSString *)fileName 
   lineNumber:(int)line 
   description:(NSString *)format,...
{
  va_list ap;

  va_start(ap, format);
  // FIXME: should be NSLog;
  fprintf(stderr, "Assertion failed in %s, file %s:%d. ",
	  [functionName cString], [fileName cString], line);
  vfprintf(stderr, [format cString], ap);
  fprintf(stderr, "\n");
  va_end(ap);
    
  [NSException raise:NSInternalInconsistencyException
	       format:@"Assertion failed in %s", [functionName cString]];
  /* NOT REACHED */
}

- (void)handleFailureInMethod:(SEL)aSelector 
   object:object 
   file:(NSString *)fileName 
   lineNumber:(int)line 
   description:(NSString *)format,...
{
  va_list ap;

  va_start(ap, format);
  // FIXME: should be NSLog;
  fprintf(stderr, "Assertion failed in %s, method %s, file %s:%d. ",
	  object_get_class_name(object), sel_get_name(aSelector),
	  [fileName cString], line);
  vfprintf(stderr, [format cString], ap);
  fprintf(stderr, "\n");
  va_end(ap);
    
  [NSException raise:NSInternalInconsistencyException
	       format:@"Assertion failed in %s, method %s",
	       object_get_class_name(object), sel_get_name(aSelector)];
  /* NOT REACHED */
}

@end

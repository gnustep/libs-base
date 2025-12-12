/**Definition of class NSScriptCommand
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: Sep 2019

   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#ifndef _NSScriptCommand_h_GNUSTEP_BASE_INCLUDE
#define _NSScriptCommand_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_0, GS_API_LATEST)

@class NSScriptCommandDescription;
@class NSScriptObjectSpecifier;
@class NSDictionary;
@class NSString;
@class NSAppleEventDescriptor;
@class NSCoder;

GS_EXPORT_CLASS
@interface NSScriptCommand : NSObject
{
  @private
  NSScriptCommandDescription *_commandDescription;
  NSDictionary *_arguments;
  NSDictionary *_evaluatedArguments;
  NSScriptObjectSpecifier *_directParameter;
  NSScriptObjectSpecifier *_receiversSpecifier;
  id _evaluatedReceivers;
  NSAppleEventDescriptor *_appleEvent;
  BOOL _isSuspended;
  NSInteger _errorNumber;
  NSString *_errorString;
}

- (id) initWithCommandDescription: (NSScriptCommandDescription *)commandDef;

- (id) initWithCoder: (NSCoder *)coder;

- (NSScriptCommandDescription *) commandDescription;

- (NSDictionary *) arguments;
- (void) setArguments: (NSDictionary *)args;

- (NSDictionary *) evaluatedArguments;

- (NSScriptObjectSpecifier *) directParameter;
- (void) setDirectParameter: (NSScriptObjectSpecifier *)directParameter;

- (id) evaluatedReceivers;

- (BOOL) isWellFormed;

- (id) performDefaultImplementation;

- (id) executeCommand;

- (void) suspendExecution;
- (void) resumeExecutionWithResult: (id)result;

- (NSScriptObjectSpecifier *) receiversSpecifier;
- (void) setReceiversSpecifier: (NSScriptObjectSpecifier *)receiversRef;

- (id) currentCommand;

- (NSAppleEventDescriptor *) appleEvent;

- (void) setScriptErrorNumber: (NSInteger)errorNumber;
- (void) setScriptErrorString: (NSString *)errorString;
- (NSInteger) scriptErrorNumber;
- (NSString *) scriptErrorString;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSScriptCommand_h_GNUSTEP_BASE_INCLUDE */

/* Runtime MacOSX compatibility functionality
   Copyright (C) 2000 Free Software Foundation, Inc.
   
   Written by:  Richard frith-Macdonald <rfm@gnu.org>
   Date: August 1994
   
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
#include <Foundation/Foundation.h>

/*
 * Runtime MacOS-X compatibility flags.
 */
static BOOL setupDone = NO;

static BOOL	MacOSXCompatible = NO;
static BOOL	MacOSXCompatibleGeometry = NO;
static BOOL	MacOSXCompatiblePropertyLists = NO;

/*
 * A trivial class to monitor user defaults to see how we should be
 * producing strings describing geometry structures.
 */
@interface GSBaseDefaultObserver : NSObject
+ (void) defaultsChanged: (NSNotification*)aNotification;
@end
@implementation GSBaseDefaultObserver
+ (void) defaultsChanged: (NSNotification*)aNotification
{
  NSUserDefaults	*defaults = [NSUserDefaults standardUserDefaults];
  id			def;
  Class			sClass = [NSString class];

  MacOSXCompatible = [defaults boolForKey: @"GSMacOSXCompatible"];

  def = [defaults objectForKey: @"GSMacOSXCompatibleGeometry"];
  if (def != nil && [def isKindOfClass: sClass] == YES)
    {
      MacOSXCompatibleGeometry = [def boolValue];
    }
  else
    {
      MacOSXCompatibleGeometry = MacOSXCompatible;
    }
  def = [defaults objectForKey: @"GSMacOSXCompatiblePropertyLists"];
  if (def != nil && [def isKindOfClass: sClass] == YES)
    {
      MacOSXCompatiblePropertyLists = [def boolValue];
    }
  else
    {
      MacOSXCompatiblePropertyLists = MacOSXCompatible;
    }
}
@end

static void
compatibilitySetup()
{
  if (setupDone == NO)
    {
      setupDone = YES;
      [[NSNotificationCenter defaultCenter]
	addObserver: [GSBaseDefaultObserver class]
	   selector: @selector(defaultsChanged:)
	       name: NSUserDefaultsDidChangeNotification
	     object: nil];
      [[GSBaseDefaultObserver class] defaultsChanged: nil];
    }
}

BOOL GSMacOSXCompatible()
{
  if (setupDone == NO)
    compatibilitySetup();
  return MacOSXCompatible;
}

BOOL GSMacOSXCompatibleGeometry()
{
  if (setupDone == NO)
    compatibilitySetup();
  return MacOSXCompatibleGeometry;
}

BOOL GSMacOSXCompatiblePropertyLists()
{
  if (setupDone == NO)
    compatibilitySetup();
  return MacOSXCompatiblePropertyLists;
}


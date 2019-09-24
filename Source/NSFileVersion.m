/* Definition of class NSFileVersion
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   Implemented by: Gregory Casamento <greg.casamento@gmail.com>
   Date: Sep 2019
   Original File by: Daniel Ferreira

   This file is part of the GNUstep Library.
   
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/

#include <Foundation/NSFileVersion.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSError.h>
#include <Foundation/NSString.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSPersonNameComponents.h>

@interface NSFileVersion (Private)
- (void) _setURL: (NSURL *)u;
@end

@implementation NSFileVersion (Private)
- (void) _setURL: (NSURL *)u
{
  ASSIGNCOPY(_fileURL, u);
}

- (void) _setContentsURL: (NSURL *)u
{
  ASSIGNCOPY(_contentsURL, u);
}
@end

@implementation NSFileVersion

// Initializers
+ (NSFileVersion *)currentVersionOfItemAtURL: (NSURL *)url
{
  NSFileVersion *fileVersion = AUTORELEASE([[NSFileVersion alloc] init]);
  if (fileVersion != nil)
    {
      [fileVersion setURL: url];
      [fileVersion setContentsURL: url];
      
    }
  return fileVersion;
}

+ (NSArray *)otherVersionsOfItemAtURL: (NSURL *)url
{
  return nil;
}

+ (NSFileVersion *)versionOfItemAtURL: (NSURL *)url
              forPersistentIdentifier: (id)persistentIdentifier
{
  return nil;
}

+ (NSURL *)temporaryDirectoryURLForNewVersionOfItemAtURL: (NSURL *)url
{
  return nil;
}

+ (NSFileVersion *)addVersionOfItemAtURL: (NSURL *)url 
                       withContentsOfURL: (NSURL *)contentsURL 
                                 options: (NSFileVersionAddingOptions)options 
                                   error: (NSError **)outError
{
  return nil;
}

+ (NSArray *)unresolvedConflictVersionsOfItemAtURL: (NSURL *)url
{
  return nil;
}

+ (BOOL)removeOtherVersionsOfItemAtURL: (NSURL *)url 
                                 error: (NSError **)outError
{
  return NO;
}

// Instance methods...
- (instancetype) init
{
  self = [super init];
  if(self != nil)
    {
      _isDiscardable = NO;
      _isResolved = NO;
      _modificationDate = [[NSDate alloc] init];
      _fileURL = nil;
      _contentsURL = nil;
      _persistentIdentifier = nil;
      _nonLocalVersion = nil;
      _hasThumbnail = NO;
      _hasLocalContents = YES;
      _conflict = NO;
      _localizedName = nil;
      _localizedNameOfSavingComputer = nil;      
    }
  return self;
}

- (BOOL) isDiscardable
{
  return _isDiscardable;
}
- (void) setDiscardable: (BOOL)flag
{
  _isDiscardable = flag;
}

- (BOOL) isResolved
{
  return _isResolved;
}

- (void) setResolved: (BOOL)flag
{
  _isResolved = flag;
}

- (NSDate *) modificationDate
{
  return _modificationDate;
}

- (NSPersonNameComponents *) originatorNameComponents
{
  return nil;
}

- (NSString *) localizedName
{
  return _localizedName;
}

- (NSString *) localizedNameOfSavingComputer
{
  return _localizedNameOfSavingComputer;
}

- (BOOL) hasLocalContents
{
  return _hasLocalContents;
}

- (BOOL) hasThumbnail
{
  return _hasThumbnail;
}

- (NSURL *) URL
{
  return _fileURL;
}

- (BOOL) conflict
{
  return _conflict;
}

- (id<NSCoding>) persistentIdentifier
{
  return _persistentIdentifier;
}

- (BOOL) removeAndReturnError: (NSError **)outError
{
  outError = NULL;
  return NO;
}

- (NSURL *) replaceItemAtURL: (NSURL *)url
                     options: (NSFileVersionReplacingOptions)options
                       error: (NSError **)error
{
  return nil;
}

@end

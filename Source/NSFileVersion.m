#include <Foundation/NSFileVersion.h>

@implementation NSFileVersion

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
  return nil;
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

/* Definition of class NSFileCoordinator
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   Implemented by: 	Gregory Casamento <greg.casamento@gmail.com>
   Date: 	Sep 2019
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

#import <Foundation/NSFileCoordinator.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSArray.h>

@implementation NSFileAccessIntent
- (instancetype) init
{
  self = [super init];
  if(self != nil)
    {
      _url = nil;
      _isRead = NO;
      _options = 0L;
    }
  return self;
}

+ (instancetype) readingIntentWithURL: (NSURL *)url
                              options: (NSFileCoordinatorReadingOptions)options
{
  NSFileAccessIntent *result = [[self alloc] init];
  ASSIGNCOPY(result->_url, url);
  result->_options = options;
  return nil;
}

+ (instancetype) writingIntentWithURL: (NSURL *)url
                              options: (NSFileCoordinatorWritingOptions)options
{
  return nil;
}

- (NSURL *) URL
{
  return nil;
}
@end

@implementation NSFileCoordinator

+ (void) initialize
{
}

+ (NSArray *) filePresenters
{
  return nil;
}

- (NSString *) purposeIdentifier
{
  return nil;
}

- (void) setPurposeIdentifier: (NSString *)ident  // copy
{
}

- (void)cancel
{
}

- (void)coordinateAccessWithIntents: (NSArray *)intents
                              queue: (NSOperationQueue *)queue
                         byAccessor: (GSAccessorCallbackHandler)accessor
{
}

- (void)coordinateReadingItemAtURL: (NSURL *)readingURL
                           options: (NSFileCoordinatorReadingOptions)readingOptions
                  writingItemAtURL: (NSURL *)writingURL
                           options: (NSFileCoordinatorWritingOptions)writingOptions
                             error: (NSError **)outError
                        byAccessor: (GSNoEscapeReadWriteHandler)readerWriter
{
}
                 
- (void)coordinateReadingItemAtURL: (NSURL *)url
                           options: (NSFileCoordinatorReadingOptions)options
                             error: (NSError **)outError
                        byAccessor: (GSNoEscapeNewURLHandler)reader
{
}
                 
- (void)coordinateWritingItemAtURL: (NSURL *)url
                           options: (NSFileCoordinatorWritingOptions)options error:(NSError **)outError
                        byAccessor: (GSNoEscapeNewURLHandler)writer
{
}

- (void)coordinateWritingItemAtURL: (NSURL *)url1
                           options: (NSFileCoordinatorWritingOptions)options1
                  writingItemAtURL: (NSURL *)url2
                           options: (NSFileCoordinatorWritingOptions)options2
                             error: (NSError **)outError
                        byAccessor: (GSDualWriteURLCallbackHandler)writer
{
}

- (void)itemAtURL:(NSURL *)oldURL didMoveToURL: (NSURL *)newURL
{
}

- (void)itemAtURL:(NSURL *)oldURL willMoveToURL: (NSURL *)newURL 
{
}

- (void)itemAtURL:(NSURL *)url didChangeUbiquityAttributes: (NSSet *)attributes
{
}

- (void)prepareForReadingItemsAtURLs: (NSArray *)readingURLs
                             options: (NSFileCoordinatorReadingOptions)readingOptions
                  writingItemsAtURLs: (NSArray *)writingURLs
                             options: (NSFileCoordinatorWritingOptions)writingOptions
                               error: (NSError **)outError
                          byAccessor: (GSAccessorHandlerBlock)batchAccessor
{
}

@end

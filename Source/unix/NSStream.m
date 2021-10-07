/** Implementation for NSStream for GNUStep
   Copyright (C) 2006 Free Software Foundation, Inc.

   Written by:  Derek Zhou <derekzhou@gmail.com>
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2006

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

#include "common.h"

#include <sys/stat.h>
#include <sys/types.h>

#if	defined(HAVE_FCNTL_H)
#  include	<fcntl.h>
#elif defined(HAVE_SYS_FCNTL_H)
#  include	<sys/fcntl.h>
#endif

#ifdef __ANDROID__
#  include <android/asset_manager_jni.h>
#endif

#import "Foundation/NSData.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSException.h"
#import "Foundation/NSError.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSHost.h"
#import "Foundation/NSByteOrder.h"
#import "Foundation/NSURL.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"

#import "../GSPrivate.h"
#import "../GSStream.h"
#import "../GSSocketStream.h"

// FIXME: Move this code into System Configuration framework...
CFDictionaryRef SCDynamicStoreCopyProxies(SCDynamicStoreRef store)
{
  NSMutableDictionary *proxyDict = [NSMutableDictionary dictionary];

  // Initialize...
  [proxyDict setObject: [NSNumber numberWithBool: NO] forKey: @"FTPEnable"];
  [proxyDict setObject: [NSNumber numberWithBool: NO] forKey: @"HTTPEnable"];
  [proxyDict setObject: [NSNumber numberWithBool: NO] forKey: @"HTTPSEnable"];
  [proxyDict setObject: [NSNumber numberWithBool: NO] forKey: @"RTSEnable"];
  [proxyDict setObject: [NSNumber numberWithBool: NO] forKey: @"SOCKSEnable"];

  // FIXME: add the ExceptionsList array section...
  [proxyDict setObject: [NSArray array] forKey: @"ExceptionsList"];

  // FIXME: add the per interface __SCOPED__ dictionary section in the code
  // section(s) below...
  NSDictionary *scopedProxies = [NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSArray array], @"ExceptionsList",
                                                  [NSNumber numberWithBool: NO], @"FTPEnable", 
                                                  [NSNumber numberWithBool: NO], @"HTTPEnable", 
                                                  [NSNumber numberWithBool: NO], @"HTTPSEnable", 
                                                  [NSNumber numberWithBool: NO], @"RTSEnable",
                                                  [NSNumber numberWithBool: NO], @"SOCKSEnable",
                                              nil];
  [proxyDict setObject: scopedProxies forKey: @"__SCOPED__"];

  // Setup proxy information...
  NSArray *ProxyEnvStrings = [NSArray arrayWithObjects: @"socks_proxy", @"http_proxy", @"https_proxy", nil];
  for (NSString *envProxyString in ProxyEnvStrings)
    {
      char *envproxy = getenv([envProxyString cStringUsingEncoding: NSUTF8StringEncoding]);
      if (envproxy)
        {
          NSString  *host   = nil;
          NSNumber  *port   = nil;
          NSString  *proxy  = [NSString stringWithUTF8String: envproxy];
          NSInteger  index  = [envProxyString rangeOfString: @"_"].location;
          NSString  *proto  = [envProxyString substringToIndex: index];
          NSWarnMLog(@"string: %@ proto: %@", proxy, proto);

          // Find the SOCKS proxy setting...
          if ([envProxyString isEqualToString: @"socks_proxy"])
            {
              // all_proxy variable will typically include the 'socks://' prefix...
              if ([proxy hasPrefix: @"socks://"])
                {
                  proxy = [proxy substringFromIndex: [@"socks://" length]];
                }
              NSWarnMLog(@"proxy: %@", proxy);

              // SOCKS available...
              NSInteger  index      = [proxy rangeOfString: @"="].location + 1;
              NSArray   *socksProxy = [proxy componentsSeparatedByString: @":"];
              if (0 == [socksProxy count])
                {
                  NSWarnMLog(@"error processing SOCKS proxy info for (%@)", proxy);
                }
              else
                {
                  host              = [socksProxy objectAtIndex: 0];
                  NSInteger portnum = ([socksProxy count] > 1 ? [[socksProxy objectAtIndex: 1] integerValue] : 8080);
                  port              = [NSNumber numberWithInteger: portnum];
                  NSWarnMLog(@"SOCKS - host: %@ port: %@", host, port);

                  // Setup the proxy dictionary information and...
                  [proxyDict setObject: host forKey: NSStreamSOCKSProxyHostKey];
                  [proxyDict setObject: port forKey: NSStreamSOCKSProxyPortKey];
                  // This key is NOT in the returned dictionary on Cocoa...
                  [proxyDict setObject: NSStreamSOCKSProxyVersion5 forKey: NSStreamSOCKSProxyVersionKey];
                  [proxyDict setObject: [NSNumber numberWithBool: YES] forKey: @"SOCKSEnable"];
                }
            }
          else if ([envProxyString isEqualToString: @"http_proxy"])
            {
              // all_proxy variable will typically include the 'socks://' prefix...
              if ([proxy hasPrefix: @"http://"])
                {
                  proxy = [proxy substringFromIndex: [@"http://" length]];
                }
              NSWarnMLog(@"proxy: %@", proxy);

              // HTTP available...
              NSArray   *socksProxy = [proxy componentsSeparatedByString: @":"];
              if (0 == [socksProxy count])
                {
                  NSWarnMLog(@"error processing HTTP proxy info for (%@)", proxy);
                }
              else
                {
                  host              = [socksProxy objectAtIndex: 0];
                  NSInteger portnum = ([socksProxy count] > 1 ? [[socksProxy objectAtIndex: 1] integerValue] : 8080);
                  port              = [NSNumber numberWithInteger: portnum];
                  NSWarnMLog(@"HTTP - host: %@ port: %@", host, port);

                  // Setup the proxy dictionary information and...
                  [proxyDict setObject: host forKey: kCFStreamPropertyHTTPProxyHost];
                  [proxyDict setObject: port forKey: kCFStreamPropertyHTTPProxyPort];
                  [proxyDict setObject: [NSNumber numberWithBool: YES] forKey: @"HTTPEnable"];
                }
            }
          else if ([envProxyString isEqualToString: @"https_proxy"])
            {
              // all_proxy variable will typically include the 'socks://' prefix...
              if ([proxy containsString: @"https://"])
                {
                  proxy = [proxy substringFromIndex: [@"https://" length]];
                }
              NSWarnMLog(@"proxy: %@", proxy);

              // HTTPS available...
              NSArray   *socksProxy = [proxy componentsSeparatedByString: @":"];
              if (0 == [socksProxy count])
                {
                  NSWarnMLog(@"error processing HTTPS proxy info for (%@)", proxy);
                }
              else
                {
                  host              = [socksProxy objectAtIndex: 0];
                  NSInteger portnum = ([socksProxy count] > 1 ? [[socksProxy objectAtIndex: 1] integerValue] : 8080);
                  port              = [NSNumber numberWithInteger: portnum];
                  NSWarnMLog(@"HTTPS - host: %@ port: %@", host, port);

                  // Setup the proxy dictionary information and...
                  [proxyDict setObject: host forKey: kCFStreamPropertyHTTPSProxyHost];
                  [proxyDict setObject: port forKey: kCFStreamPropertyHTTPSProxyPort];
                  [proxyDict setObject: [NSNumber numberWithBool: YES] forKey: @"HTTPSEnable"];
                }
            }
        }
  }

  NSWarnMLog(@"proxies: %@", proxyDict);

  return [proxyDict copy];
}

/** 
 * The concrete subclass of NSInputStream that reads from a file
 */
@interface GSFileInputStream : GSInputStream
{
@private
  NSString *_path;
#ifdef __ANDROID__
  AAsset *_asset;
#endif
}
@end

@interface GSLocalInputStream : GSSocketInputStream
/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr;

@end

/**
 * The concrete subclass of NSOutputStream that writes to a file
 */
@interface GSFileOutputStream : GSOutputStream
{
@private
  NSString *_path;
  BOOL _shouldAppend;
}
@end

@interface GSLocalOutputStream : GSSocketOutputStream
/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr;

@end

@interface GSLocalServerStream : GSSocketServerStream
@end

@implementation GSFileInputStream

- (id) initWithFileAtPath: (NSString *)path
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(_path, path);
    }
  return self;
}

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  DESTROY(_path);
  [super dealloc];
}

- (NSInteger) read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
  int readLen;

  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"zero byte read write requested"];
    }

  _events &= ~NSStreamEventHasBytesAvailable;

  if ([self streamStatus] == NSStreamStatusClosed)
    {
      return 0;
    }

#ifdef __ANDROID__
  if (_asset)
  {
    readLen = AAsset_read(_asset, buffer, len);
  }
  else
#endif
  {
    readLen = read((intptr_t)_loopID, buffer, len);
  }
  if (readLen < 0 && errno != EAGAIN && errno != EINTR)
    {
      [self _recordError];
      readLen = -1;
    }
  else if (readLen == 0)
    {
      [self _setStatus: NSStreamStatusAtEnd];
    }
  return readLen;
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (NSUInteger *)len
{
  return NO;
}

- (BOOL) hasBytesAvailable
{
  if ([self _isOpened] && [self streamStatus] != NSStreamStatusAtEnd)
    return YES;
  return NO;
}

- (id) propertyForKey: (NSString *)key
{
  if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
      off_t offset = 0;

      if ([self _isOpened])
        {
#ifdef __ANDROID__
          if (_asset)
            {
              offset = AAsset_seek(_asset, 0, SEEK_CUR);
            }
          else
#endif
            {
              offset = lseek((intptr_t)_loopID, 0, SEEK_CUR);
            }
        }
      return [NSNumber numberWithLong: offset];
    }
  return [super propertyForKey: key];
}

- (void) open
{
  int fd;

  fd = open([_path fileSystemRepresentation], O_RDONLY|O_NONBLOCK);
  if (fd < 0)
    {
#ifdef __ANDROID__
      _asset = [NSBundle assetForPath:_path withMode:AASSET_MODE_STREAMING];
      if (!_asset)
#endif
        {
          [self _recordError];
          return;
        }
    }
  _loopID = (void*)(intptr_t)fd;
  [super open];
}

- (void) close
{
#ifdef __ANDROID__
  if (_asset)
    {
      AAsset_close(_asset);
    }
  else
#endif
    {
      int closeReturn = close((intptr_t)_loopID);

      if (closeReturn < 0)
        [self _recordError];
    }
  [super close];
}

- (void) _dispatch
{
  if ([self streamStatus] == NSStreamStatusOpen)
    {
      [self _sendEvent: NSStreamEventHasBytesAvailable];
    }
  else
    {
      NSLog(@"_dispatch with unexpected status %"PRIuPTR, [self streamStatus]);
    }
}
@end


@implementation GSLocalInputStream 

- (id) initToAddr: (NSString*)addr
{
  if ((self = [super init]) != nil)
    {
      if ([self _setSocketAddress: addr port: 0 family: AF_UNIX] == NO)
	{
	  DESTROY(self);
	}
    }
  return self;
}

@end

@implementation GSFileOutputStream

- (id) initToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(_path, path);
      // so that unopened access will fail
      _shouldAppend = shouldAppend;
    }
  return self;
}

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  RELEASE(_path);
  [super dealloc];
}

- (NSInteger) write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
  int writeLen;

  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"zero byte length write requested"];
    }

  _events &= ~NSStreamEventHasSpaceAvailable;

  if ([self streamStatus] == NSStreamStatusClosed)
    {
      return 0;
    }

  writeLen = write((intptr_t)_loopID, buffer, len);
  if (writeLen < 0 && errno != EAGAIN && errno != EINTR)
    [self _recordError];
  return writeLen;
}

- (BOOL) hasSpaceAvailable
{
  if ([self _isOpened])
    return YES;
  return NO;
}

- (void) open
{
  int fd;
  int flag = O_WRONLY | O_NONBLOCK | O_CREAT;
  mode_t mode = 0666;

  if (_shouldAppend)
    flag = flag | O_APPEND;
  else
    flag = flag | O_TRUNC;
  fd = open([_path fileSystemRepresentation], flag, mode);
  if (fd < 0)
    {  // make an error
      [self _recordError];
      return;
    }
  _loopID = (void*)(intptr_t)fd;
  [super open];
}

- (void) close
{
  int closeReturn = close((intptr_t)_loopID);
  if (closeReturn < 0)
    [self _recordError];
  [super close];
}

- (id) propertyForKey: (NSString *)key
{
  if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
      off_t offset = 0;

      if ([self _isOpened])
        offset = lseek((intptr_t)_loopID, 0, SEEK_CUR);
      return [NSNumber numberWithLong: offset];
    }
  return [super propertyForKey: key];
}

- (void) _dispatch
{
  if ([self streamStatus] == NSStreamStatusOpen)
    {
      [self _sendEvent: NSStreamEventHasSpaceAvailable];
    }
  else
    {
      NSLog(@"_dispatch with unexpected status %"PRIuPTR, [self streamStatus]);
    }
}
@end


@implementation GSLocalOutputStream 

- (id) initToAddr: (NSString*)addr
{
  if ((self = [super init]) != nil)
    {
      if ([self _setSocketAddress: addr port: 0 family: AF_UNIX] == NO)
	{
	  DESTROY(self);
	}
    }
  return self;
}

@end

@implementation NSStream

+ (void) getStreamsToHost: (NSHost *)host 
                     port: (NSInteger)port 
              inputStream: (NSInputStream **)inputStream 
             outputStream: (NSOutputStream **)outputStream
{
  NSString *address = host ? (id)[host address] : (id)@"127.0.0.1";
  id ins = nil;
  id outs = nil;

  // try ipv4 first
  ins = AUTORELEASE([[GSInetInputStream alloc]
    initToAddr: address port: port]);
  outs = AUTORELEASE([[GSInetOutputStream alloc]
    initToAddr: address port: port]);
  if (!ins)
    {
#if	defined(PF_INET6)
      ins = AUTORELEASE([[GSInet6InputStream alloc]
	initToAddr: address port: port]);
      outs = AUTORELEASE([[GSInet6OutputStream alloc]
	initToAddr: address port: port]);
#endif
    }  

  // Setup proxy information...
  NSDictionary *proxyDict = SCDynamicStoreCopyProxies(NULL);

  // and if available...
  if ([proxyDict count])
    {
      // store in the streams...
      if ([[proxyDict objectForKey: @"SOCKSEnable"] boolValue])
        {
          NSDictionary *proxy = [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [proxyDict objectForKey: NSStreamSOCKSProxyHostKey], NSStreamSOCKSProxyHostKey,
                                                   [proxyDict objectForKey: NSStreamSOCKSProxyPortKey], NSStreamSOCKSProxyPortKey,
                                              nil]; 

          [ins setProperty: proxy forKey: NSStreamSOCKSProxyConfigurationKey];
          [outs setProperty: proxy forKey: NSStreamSOCKSProxyConfigurationKey];
        }
      if ([[proxyDict objectForKey: @"HTTPEnable"] boolValue])
        {
          NSDictionary *proxy = [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [proxyDict objectForKey: kCFStreamPropertyHTTPProxyHost], kCFStreamPropertyHTTPProxyHost,
                                                   [proxyDict objectForKey: kCFStreamPropertyHTTPProxyPort], kCFStreamPropertyHTTPProxyPort,
                                              nil]; 

          [ins setProperty: proxy forKey: kCFStreamPropertyHTTPProxy];
          [outs setProperty: proxy forKey: kCFStreamPropertyHTTPProxy];
        }
      if ([[proxyDict objectForKey: @"HTTPSEnable"] boolValue])
        {
          [ins setProperty: [proxyDict objectForKey: kCFStreamPropertyHTTPSProxyHost] forKey: kCFStreamPropertyHTTPSProxyHost];
          [ins setProperty: [proxyDict objectForKey: kCFStreamPropertyHTTPSProxyHost] forKey: kCFStreamPropertyHTTPSProxyHost];
          [outs setProperty: [proxyDict objectForKey: kCFStreamPropertyHTTPSProxyPort] forKey: kCFStreamPropertyHTTPSProxyPort];
          [outs setProperty: [proxyDict objectForKey: kCFStreamPropertyHTTPSProxyPort] forKey: kCFStreamPropertyHTTPSProxyPort];
        }
    }
  
  if (inputStream)
    {
      [ins _setSibling: outs];
      *inputStream = (NSInputStream*)ins;
    }
  if (outputStream)
    {
      [outs _setSibling: ins];
      *outputStream = (NSOutputStream*)outs;
    }
}

+ (void) getLocalStreamsToPath: (NSString *)path 
                   inputStream: (NSInputStream **)inputStream 
                  outputStream: (NSOutputStream **)outputStream
{
  id ins = nil;
  id outs = nil;

  ins = AUTORELEASE([[GSLocalInputStream alloc] initToAddr: path]);
  outs = AUTORELEASE([[GSLocalOutputStream alloc] initToAddr: path]);
  if (inputStream)
    {
      [ins _setSibling: outs];
      *inputStream = (NSInputStream*)ins;
    }
  if (outputStream)
    {
      [outs _setSibling: ins];
      *outputStream = (NSOutputStream*)outs;
    }
  return;
}

+ (void) pipeWithInputStream: (NSInputStream **)inputStream 
                outputStream: (NSOutputStream **)outputStream
{
  id ins = nil;
  id outs = nil;
  int fds[2];
  int pipeReturn;

  // the type of the stream does not matter, since we are only using the fd
  ins = AUTORELEASE([GSLocalInputStream new]);
  outs = AUTORELEASE([GSLocalOutputStream new]);
  pipeReturn = pipe(fds);

  NSAssert(pipeReturn >= 0, @"Cannot open pipe");
  [ins _setLoopID: (void*)(intptr_t)fds[0]];
  [outs _setLoopID: (void*)(intptr_t)fds[1]];
  // no need to connect
  [ins _setPassive: YES];
  [outs _setPassive: YES];
  if (inputStream)
    *inputStream = (NSInputStream*)ins;
  if (outputStream)
    *outputStream = (NSOutputStream*)outs;
  return;
}

- (void) close
{
  [self subclassResponsibility: _cmd];
}

- (void) open
{
  [self subclassResponsibility: _cmd];
}

- (void) setDelegate: (id)delegate
{
  [self subclassResponsibility: _cmd];
}

- (id) delegate
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (BOOL) setProperty: (id)property forKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (id) propertyForKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  [self subclassResponsibility: _cmd];
}

- (void) removeFromRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode;
{
  [self subclassResponsibility: _cmd];
}

- (NSError *) streamError
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSStreamStatus) streamStatus
{
  [self subclassResponsibility: _cmd];
  return 0;
}

@end

@implementation NSInputStream

+ (id) inputStreamWithData: (NSData *)data
{
  return AUTORELEASE([[GSDataInputStream alloc] initWithData: data]);
}

+ (id) inputStreamWithFileAtPath: (NSString *)path
{
  return AUTORELEASE([[GSFileInputStream alloc] initWithFileAtPath: path]);
}

+ (id) inputStreamWithURL: (NSURL *)url
{
  if ([url isFileURL])
    {
      return [self inputStreamWithFileAtPath: [url path]];
    }
  return [self inputStreamWithData: [url resourceDataUsingCache: YES]];
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (NSUInteger *)len
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (BOOL) hasBytesAvailable
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (id) initWithData: (NSData *)data
{
  DESTROY(self);
  return [[GSDataInputStream alloc] initWithData: data];
}

- (id) initWithFileAtPath: (NSString *)path
{
  DESTROY(self);
  return [[GSFileInputStream alloc] initWithFileAtPath: path];
}

- (id) initWithURL: (NSURL *)url
{
  DESTROY(self);
  if ([url isFileURL])
    {
      return [[GSFileInputStream alloc] initWithFileAtPath: [url path]];
    }
  return [[GSDataInputStream alloc]
    initWithData: [url resourceDataUsingCache: YES]];
}

- (NSInteger) read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
  [self subclassResponsibility: _cmd];
  return -1;
}

@end

@implementation NSOutputStream

+ (id) outputStreamToBuffer: (uint8_t *)buffer capacity: (NSUInteger)capacity
{
  return AUTORELEASE([[GSBufferOutputStream alloc] 
    initToBuffer: buffer capacity: capacity]);  
}

+ (id) outputStreamToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  return AUTORELEASE([[GSFileOutputStream alloc]
    initToFileAtPath: path append: shouldAppend]);
}

+ (id) outputStreamToMemory
{
  return AUTORELEASE([[GSDataOutputStream alloc] init]);  
}

- (BOOL) hasSpaceAvailable
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (id) initToBuffer: (uint8_t *)buffer capacity: (NSUInteger)capacity
{
  DESTROY(self);
  return [[GSBufferOutputStream alloc] initToBuffer: buffer capacity: capacity];
}

- (id) initToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  DESTROY(self);
  return [[GSFileOutputStream alloc] initToFileAtPath: path
					       append: shouldAppend];  
}

- (id) initToMemory
{
  DESTROY(self);
  return [[GSDataOutputStream alloc] init];
}

- (NSInteger) write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
  [self subclassResponsibility: _cmd];
  return -1;  
}

@end

@implementation GSLocalServerStream 

- (Class) _inputStreamClass
{
  return [GSLocalInputStream class];
}

- (Class) _outputStreamClass
{
  return [GSLocalOutputStream class];
}

- (id) initToAddr: (NSString*)addr
{
  if ((self = [super init]) != nil)
    {
      if ([self _setSocketAddress: addr port: 0 family: AF_UNIX] == NO)
	{
          DESTROY(self);
        }
    }
  return self;
}

@end


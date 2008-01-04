/** Implementation for NSStream for GNUStep
   Copyright (C) 2006 Free Software Foundation, Inc.

   Written by:  Derek Zhou <derekzhou@gmail.com>
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2006

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   */
#include <unistd.h>
#include <errno.h>

#include <Foundation/NSData.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSException.h>
#include <Foundation/NSError.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSHost.h>
#include <Foundation/NSByteOrder.h>

#include "../GSStream.h"

/** 
 * The concrete subclass of NSInputStream that reads from a file
 */
@interface GSFileInputStream : GSInputStream
{
@private
  NSString *_path;
}
@end

@interface GSLocalInputStream : GSSocketInputStream
{
  @private
  struct sockaddr_un _peerAddr;
}

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
{
  @private
  struct sockaddr_un _peerAddr;
}

/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr;

@end

@interface GSLocalServerStream : GSSocketServerStream
{
  @private
  struct sockaddr_un _serverAddr;
}
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

- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len
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

  readLen = read((intptr_t)_loopID, buffer, len);
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

- (BOOL) getBuffer: (uint8_t **)buffer length: (unsigned int *)len
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
        offset = lseek((intptr_t)_loopID, 0, SEEK_CUR);
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

- (void) _dispatch
{
  if ([self streamStatus] == NSStreamStatusOpen)
    {
      [self _sendEvent: NSStreamEventHasBytesAvailable];
    }
  else
    {
      NSLog(@"_dispatch with unexpected status %d", [self streamStatus]);
    }
}
@end


@implementation GSLocalInputStream 

- (id) initToAddr: (NSString*)addr
{
  const char* real_addr = [addr fileSystemRepresentation];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sun_family = AF_LOCAL;
      if (strlen(real_addr)>sizeof(_peerAddr.sun_path)-1) // too long
	{
	  DESTROY(self);
	}
      else
	{
	  strncpy(_peerAddr.sun_path, real_addr, sizeof(_peerAddr.sun_path)-1);
	}
    }
  return self;
}

- (struct sockaddr*) _peerAddr
{
  return (struct sockaddr*)&_peerAddr;
}

- (socklen_t) _sockLen
{
  return sizeof(struct sockaddr_un);
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

- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len
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
      NSLog(@"_dispatch with unexpected status %d", [self streamStatus]);
    }
}
@end


@implementation GSLocalOutputStream 

- (id) initToAddr: (NSString*)addr
{
  const char* real_addr = [addr fileSystemRepresentation];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sun_family = AF_LOCAL;
      if (strlen(real_addr) > sizeof(_peerAddr.sun_path)-1) // too long
	{
	  DESTROY(self);
	}
      else
	{
	  strncpy(_peerAddr.sun_path, real_addr, sizeof(_peerAddr.sun_path)-1);
	}
    }
  return self;
}

- (struct sockaddr*) _peerAddr
{
  return (struct sockaddr*)&_peerAddr;
}

- (socklen_t) sockLen
{
  return sizeof(struct sockaddr_un);
}

@end

@implementation NSStream

+ (void) getStreamsToHost: (NSHost *)host 
                     port: (int)port 
              inputStream: (NSInputStream **)inputStream 
             outputStream: (NSOutputStream **)outputStream
{
  NSString *address = host ? (id)[host address] : (id)@"127.0.0.1";
  GSSocketStream *ins = nil;
  GSSocketStream *outs = nil;
  int sock;

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
      sock = socket(PF_INET6, SOCK_STREAM, 0);
#else
      sock = -1;
#endif
    }  
  else
    {
      sock = socket(PF_INET, SOCK_STREAM, 0);
    }

  NSAssert(sock >= 0, @"Cannot open socket");
  [ins _setLoopID: (void*)(intptr_t)sock];
  [outs _setLoopID: (void*)(intptr_t)sock];
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
  GSSocketStream *ins = nil;
  GSSocketStream *outs = nil;
  int sock;

  ins = AUTORELEASE([[GSLocalInputStream alloc] initToAddr: path]);
  outs = AUTORELEASE([[GSLocalOutputStream alloc] initToAddr: path]);
  sock = socket(PF_LOCAL, SOCK_STREAM, 0);

  NSAssert(sock >= 0, @"Cannot open socket");
  [ins _setLoopID: (void*)(intptr_t)sock];
  [outs _setLoopID: (void*)(intptr_t)sock];
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
  GSSocketStream *ins = nil;
  GSSocketStream *outs = nil;
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

- (BOOL) getBuffer: (uint8_t **)buffer length: (unsigned int *)len
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
  RELEASE(self);
  return [[GSDataInputStream alloc] initWithData: data];
}

- (id) initWithFileAtPath: (NSString *)path
{
  RELEASE(self);
  return [[GSFileInputStream alloc] initWithFileAtPath: path];
}

- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len
{
  [self subclassResponsibility: _cmd];
  return -1;
}

@end

@implementation NSOutputStream

+ (id) outputStreamToBuffer: (uint8_t *)buffer capacity: (unsigned int)capacity
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

- (id) initToBuffer: (uint8_t *)buffer capacity: (unsigned int)capacity
{
  RELEASE(self);
  return [[GSBufferOutputStream alloc] initToBuffer: buffer capacity: capacity];
}

- (id) initToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  RELEASE(self);
  return [[GSFileOutputStream alloc] initToFileAtPath: path
					       append: shouldAppend];  
}

- (id) initToMemory
{
  RELEASE(self);
  return [[GSDataOutputStream alloc] init];
}

- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len
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

- (socklen_t) _sockLen
{
  return sizeof(struct sockaddr_un);
}

- (struct sockaddr*) _serverAddr
{
  return (struct sockaddr*)&_serverAddr;
}

- (id) initToAddr: (NSString*)addr
{
  if ((self = [super init]) != nil)
    {
      const char* real_addr = [addr fileSystemRepresentation];

      if (strlen(real_addr) > sizeof(_serverAddr.sun_path)-1)
        {
          DESTROY(self);
        }
      else
        {
          SOCKET s;

          _serverAddr.sun_family = AF_LOCAL;
          s = socket(AF_LOCAL, SOCK_STREAM, 0);
          if (s < 0)
            {
              DESTROY(self);
            }
          else
            {
              [(GSSocketStream*)self _setSock: s];
              strncpy(_serverAddr.sun_path, real_addr,
                sizeof(_serverAddr.sun_path)-1);
            }
        }
    }
  return self;
}

@end


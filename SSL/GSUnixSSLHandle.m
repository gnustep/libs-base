/** Implementation for GSUnixSSLHandle for GNUStep
   Copyright (C) 1997-1999 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1997

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

#if     defined(__WIN32__) || defined(_WIN32) || defined(__MS_WIN32__)
#ifndef __WIN32__
#define __WIN32__
#endif
#endif

#ifdef __MINGW32__
#ifndef __MINGW__
#define __MINGW__
#endif
#ifndef __WIN32__
#define __WIN32__
#endif
#endif

#if defined(__WIN32__)
#include <windows.h>
#define GNUSTEP_BASE_SOCKET_MESSAGE (WM_USER + 1)
#endif

  /* Because openssl uses `id' as variable name sometime,
     while it is an Objective-C reserved keyword. */
  #define id id_x_
  #include <openssl/ssl.h>
  #undef id

#include <GSConfig.h>
#include <Foundation/Foundation.h>

#include <gnustep/base/UnixFileHandle.h>

#if defined(__MINGW__)
#include <winsock2.h>
#else
#include <time.h>
#include <sys/time.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>
#endif /* __MINGW__ */

#include <sys/file.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <sys/ioctl.h>
#ifdef	__svr4__
#include <sys/filio.h>
#endif
#include <netdb.h>
#include <string.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#include <errno.h>

// Maximum data in single I/O operation
#define	NETBUF_SIZE	4096

// Key to info dictionary for operation mode.
static NSString*        NotificationKey = @"NSFileHandleNotificationKey";



@interface	GSUnixSSLHandle : UnixFileHandle <GCFinalization>
{
  SSL_CTX	*ctx;
  SSL		*ssl;
  BOOL		connected;
}
- (BOOL) sslConnect;
- (void) sslDisconnect;
- (void) sslSetCertificate: (NSString*)certFile
		privateKey: (NSString*)privateKey
		 PEMpasswd: (NSString*)PEMpasswd;
@end

@implementation	GSUnixSSLHandle
+ (void) initialize
{
  if (self == [GSUnixSSLHandle class])
    {
      SSL_library_init();
    }
}

- (NSData*) availableData
{
  char		buf[NETBUF_SIZE];
  NSMutableData	*d;
  int		len;

  [self checkRead];
  if (isNonBlocking == YES)
    [self setNonBlocking: NO];
  d = [NSMutableData dataWithCapacity: 0];
  if (isStandardFile)
    {
      while ((len = read(descriptor, buf, sizeof(buf))) > 0)
	{
	  [d appendBytes: buf length: len];
	}
    }
  else
    {
      if (connected)
	{
	  if ((len = SSL_read(ssl, buf, sizeof(buf))) > 0)
	    {
	      [d appendBytes: buf length: len];
	    }
	}
      else
	{
	  if ((len = read(descriptor, buf, sizeof(buf))) > 0)
	    {
	      [d appendBytes: buf length: len];
	    }
	}
    }
  if (len < 0)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"unable to read from descriptor - %s",
                  GSLastErrorStr(errno)];
    }
  return d;
}

- (void) closeFile
{
  [self sslDisconnect];
  [super closeFile];
}

- (void) gcFinalize
{
  [self sslDisconnect];
  [super gcFinalize];
}

- (NSData*) readDataOfLength: (unsigned)len
{
  NSMutableData	*d;
  int		got;

  [self checkRead];
  if (isNonBlocking == YES)
    [self setNonBlocking: NO];
  if (len <= 65536)
    {
      char	*buf;

      buf = NSZoneMalloc(NSDefaultMallocZone(), len);
      d = [NSMutableData dataWithBytesNoCopy: buf length: len];
      if ((got = SSL_read(ssl, [d mutableBytes], len)) < 0)
	{
	  [NSException raise: NSFileHandleOperationException
		      format: @"unable to read from descriptor - %s",
		      GSLastErrorStr(errno)];
	}
      [d setLength: got];
    }
  else
    {
      char	buf[NETBUF_SIZE];

      d = [NSMutableData dataWithCapacity: 0];
      do
	{
	  int	chunk = len > sizeof(buf) ? sizeof(buf) : len;

	  if (connected)
	    {
	      got = SSL_read(ssl, buf, chunk);
	    }
	  else
	    {
	      got = read(descriptor, buf, chunk);
	    }
	  if (got > 0)
	    {
	      [d appendBytes: buf length: got];
	      len -= got;
	    }
	  else if (got < 0)
	    {
	      [NSException raise: NSFileHandleOperationException
			  format: @"unable to read from descriptor - %s",
			  GSLastErrorStr(errno)];
	    }
	}
      while (len > 0 && got > 0);
    }
  return d;
}

- (NSData*) readDataToEndOfFile
{
  char		buf[NETBUF_SIZE];
  NSMutableData	*d;
  int		len;

  [self checkRead];
  if (isNonBlocking == YES)
    [self setNonBlocking: NO];
  d = [NSMutableData dataWithCapacity: 0];
  if (connected)
    {
      while ((len = SSL_read(ssl, buf, sizeof(buf))) > 0)
	{
	  [d appendBytes: buf length: len];
	}
    }
  else
    {
      while ((len = read(descriptor, buf, sizeof(buf))) > 0)
	{
	  [d appendBytes: buf length: len];
	}
    }
  if (len < 0)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"unable to read from descriptor - %s",
                  GSLastErrorStr(errno)];
    }
  return d;
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  NSString	*operation;

  NSDebugMLLog(@"NSFileHandle", @"%@ event: %d", self, type);

  if (isNonBlocking == NO)
    {
      [self setNonBlocking: YES];
    }

  if (type == ET_RDESC)
    {
      operation = [readInfo objectForKey: NotificationKey];
      if (operation == NSFileHandleConnectionAcceptedNotification)
	{
	  struct sockaddr_in	buf;
	  int			desc;
	  int			blen = sizeof(buf);

	  desc = accept(descriptor, (struct sockaddr*)&buf, &blen);
	  if (desc < 0)
	    {
	      NSString	*s;

	      s = [NSString stringWithFormat: @"Accept attempt failed - %s",
		GSLastErrorStr(errno)];
	      [readInfo setObject: s forKey: GSFileHandleNotificationError];
	    }
	  else
	    { // Accept attempt completed.
	      UnixFileHandle		*h;
	      struct sockaddr_in	sin;
	      int			size = sizeof(sin);

	      h = [[UnixFileHandle alloc] initWithFileDescriptor: desc
						  closeOnDealloc: YES];
	      getpeername(desc, (struct sockaddr*)&sin, &size);
	      [h setAddr: &sin];
	      [readInfo setObject: h
			   forKey: NSFileHandleNotificationFileHandleItem];
	      RELEASE(h);
	    }
	  [self postReadNotification];
	}
      else if (operation == NSFileHandleDataAvailableNotification)
	{
	  [self postReadNotification];
	}
      else
	{
	  NSMutableData	*item;
	  int		length;
	  int		received = 0;
	  char		buf[NETBUF_SIZE];

	  item = [readInfo objectForKey: NSFileHandleNotificationDataItem];
	  /*
	   * We may have a maximum data size set...
	   */
	  if (readMax > 0)
	    {
	      length = readMax - [item length];
	      if (length > sizeof(buf))
		{
		  length = sizeof(buf);
		}
	    }
	  else
	    {
	      length = sizeof(buf);
	    }

#if	USE_ZLIB
	  if (gzDescriptor != 0)
	    {
	      received = gzread(gzDescriptor, buf, length);
	    }
	  else
#endif
	  if (connected)
	    {
	      received = SSL_read(ssl, buf, length);
	    }
	  else
	    {
	      received = read(descriptor, buf, length);
	    }
	  if (received == 0)
	    { // Read up to end of file.
	      [self postReadNotification];
	    }
	  else if (received < 0)
	    {
	      if (errno != EAGAIN && errno != EINTR)
		{
		  NSString	*s;

		  s = [NSString stringWithFormat: @"Read attempt failed - %s",
		    GSLastErrorStr(errno)];
		  [readInfo setObject: s forKey: GSFileHandleNotificationError];
		  [self postReadNotification];
		}
	    }
	  else
	    {
	      [item appendBytes: buf length: received];
	      if (readMax < 0 || (readMax > 0 && [item length] == readMax))
		{
		  // Read a single chunk of data
		  [self postReadNotification];
		}
	    }
	}
    }
  else
    {
      extern NSString * const	GSSOCKSConnect;
      NSMutableDictionary	*info;

      info = [writeInfo objectAtIndex: 0];
      operation = [info objectForKey: NotificationKey];
      if (operation == GSFileHandleConnectCompletionNotification
	|| operation == GSSOCKSConnect)
	{ // Connection attempt completed.
	  int	result;
	  int	len = sizeof(result);

	  if (getsockopt(descriptor, SOL_SOCKET, SO_ERROR,
	    (char*)&result, &len) == 0 && result != 0)
	    {
	      NSString	*s;

	      s = [NSString stringWithFormat: @"Connect attempt failed - %s",
		GSLastErrorStr(result)];
	      [info setObject: s forKey: GSFileHandleNotificationError];
	    }
	  else
	    {
	      readOK = YES;
	      writeOK = YES;
	    }
	  connectOK = NO;
	  [self postWriteNotification];
	}
      else
	{
	  NSData	*item;
	  int		length;
	  const void	*ptr;

	  item = [info objectForKey: NSFileHandleNotificationDataItem];
	  length = [item length];
	  ptr = [item bytes];
	  if (writePos < length)
	    {
	      int	written;

#if	USE_ZLIB
	      if (gzDescriptor != 0)
		{
		  written = gzwrite(gzDescriptor, (char*)ptr+writePos,
		    length-writePos);
		}
	      else
#endif
	      if (connected)
		{
		  written = SSL_write(ssl, (char*)ptr + writePos, 
		    length - writePos);
		}
	      else
		{
		  written = write(descriptor, (char*)ptr + writePos, 
		    length - writePos);
		}
	      if (written <= 0)
		{
		  if (written < 0 && errno != EAGAIN && errno != EINTR)
		    {
		      NSString	*s;

		      s = [NSString stringWithFormat:
			@"Write attempt failed - %s", GSLastErrorStr(errno)];
		      [info setObject: s forKey: GSFileHandleNotificationError];
		      [self postWriteNotification];
		    }
		}
	      else
		{
		  writePos += written;
		}
	    }
	  if (writePos >= length)
	    { // Write operation completed.
	      [self postWriteNotification];
	    }
	}
    }
}

- (BOOL) sslConnect
{
  int		ret;
  int		err;
  NSRunLoop	*loop;

  if (connected == YES)
    {
      return YES;	/* Already connected.	*/
    }
  if (isStandardFile == YES)
    {
      NSLog(@"Attempt to make ssl connection to a standard file");
      return NO;
    }

  /*
   * Ensure we have a context and handle to connect with.
   */
  if (ctx == 0)
    {
      ctx = SSL_CTX_new(SSLv23_client_method());
    }
  if (ssl == 0)
    {
      ssl = SSL_new(ctx);
    }

  ret = SSL_set_fd(ssl, descriptor);
  loop = [NSRunLoop currentRunLoop];
  [loop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]];
  ret = SSL_connect(ssl);
  if (ret != 1)
    {
      int		e = errno;
      NSDate		*final;
      NSDate		*when;
      NSTimeInterval	last = 0.0;
      NSTimeInterval	limit = 0.1;

      final = [[NSDate alloc] initWithTimeIntervalSinceNow: 20.0];
      when = [NSDate alloc];

      err = SSL_get_error(ssl, ret);
      while ((err == SSL_ERROR_WANT_READ || err == SSL_ERROR_WANT_WRITE)
	&& [final timeIntervalSinceNow] > 0.0)
	{
	  NSTimeInterval	tmp = limit;

	  limit += last;
	  last = tmp;
	  when = [when initWithTimeIntervalSinceNow: limit];
	  [loop runUntilDate: when];
	  ret = SSL_connect(ssl);
	  if (ret != 1)
	    {
	      e = errno;
	      err = SSL_get_error(ssl, ret);
	    }
	  else
	    {
	      err = SSL_ERROR_NONE;
	    }
	}
      RELEASE(when);
      RELEASE(final);
      if (err != SSL_ERROR_NONE)
	{
	  NSString	*str;

	  switch (err)
	    {
	      case SSL_ERROR_NONE:
		str = @"No error: really helpful";
		break;
	      case SSL_ERROR_ZERO_RETURN:
		str = @"Zero Return error";
		break;
	      case SSL_ERROR_WANT_READ:
		str = @"Want Read Error";
		break;
	      case SSL_ERROR_WANT_WRITE:
		str = @"Want Write Error";
		break;
	      case SSL_ERROR_WANT_X509_LOOKUP:
		str = @"Want X509 Lookup Error";
		break;
	      case SSL_ERROR_SYSCALL:
		str = [NSString stringWithFormat: @"Syscall error %d - %s",
		  e, GSLastErrorStr(e)];
		break;
	      case SSL_ERROR_SSL:
		str = @"SSL Error: really helpful";
		break;
	      default:
		str = @"Standard Unix Error: really helpful";
		break;
	    }
	  NSLog(@"unable to make SSL connection to %@:%@ - %@",
	    address, service, str);
	  return NO;
	}
    }
  connected = YES;
  return YES;
}

- (void) sslDisconnect
{
  if (ssl != 0)
    {
      if (connected == YES)
	{
	  SSL_shutdown(ssl);
	}
      SSL_clear(ssl);
      SSL_free(ssl);
      ssl = 0;
    }
  if (ctx != 0)
    {
      SSL_CTX_free(ctx);
      ctx = 0;
    }
  connected = NO;
}

- (void) sslSetCertificate: (NSString*)certFile
		privateKey: (NSString*)privateKey
		 PEMpasswd: (NSString*)PEMpasswd
{
  if (isStandardFile == YES)
    {
      NSLog(@"Attempt to set ssl certificate for a standard file");
      return;
    }
  /*
   * Ensure we have a context to set the certificate for.
   */
  if (ctx == 0)
    {
      ctx = SSL_CTX_new(SSLv23_client_method());
    }
  if ([PEMpasswd length] > 0)
    {
      SSL_CTX_set_default_passwd_cb_userdata(ctx, (char*)[PEMpasswd cString]);
    }
  if ([certFile length] > 0)
    {
      SSL_CTX_use_certificate_file(ctx, [certFile cString], X509_FILETYPE_PEM);
    }
  if ([privateKey length] > 0)
    {
      SSL_CTX_use_PrivateKey_file(ctx, [privateKey cString], X509_FILETYPE_PEM);
    }
}

- (void) writeData: (NSData*)item
{
  int		rval = 0;
  const void	*ptr = [item bytes];
  unsigned int	len = [item length];
  unsigned int	pos = 0;

  [self checkWrite];
  if (isNonBlocking == YES)
    {
      [self setNonBlocking: NO];
    }
  while (pos < len)
    {
      int	toWrite = len - pos;

      if (toWrite > NETBUF_SIZE)
	{
	  toWrite = NETBUF_SIZE;
	}
      if (connected)
	{
	  rval = SSL_write(ssl, (char*)ptr+pos, toWrite);
	}
      else
	{
	  rval = write(descriptor, (char*)ptr+pos, toWrite);
	}
      if (rval < 0)
	{
	  if (errno == EAGAIN == errno == EINTR)
	    {
	      rval = 0;
	    }
	  else
	    {
	      break;
	    }
	}
      pos += rval;
    }
  if (rval < 0)
    {
      [NSException raise: NSFileHandleOperationException
                  format: @"unable to write to descriptor - %s",
                  GSLastErrorStr(errno)];
    }
}
@end


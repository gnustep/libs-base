/** Implementation for GSSSLHandle for GNUStep
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

#include <gnustep/base/GSFileHandle.h>

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



@interface	GSSSLHandle : GSFileHandle <GCFinalization>
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

@implementation	GSSSLHandle
+ (void) initialize
{
  if (self == [GSSSLHandle class])
    {
      SSL_library_init();
    }
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

- (int) read: (void*)buf length: (int)len
{
  if (connected)
    {
      return SSL_read(ssl, buf, len);
    }
  return [super read: buf length: len];
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
		str = @"Standard system error: really helpful";
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

- (int) write: (const void*)buf length: (int)len
{
  if (connected)
    {
      return SSL_write(ssl, buf, len);
    }
  return [super write: buf length: len];
}

@end


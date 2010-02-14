/** Implementation for GSSSLHandle for GNUStep
   Copyright (C) 1997-1999 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1997

   This file is part of the GNUstep Base Library.

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


#include "config.h"

#if     defined(__WIN32__) || defined(_WIN32) || defined(__MS_WIN32__)
#ifndef __WIN32__
#define __WIN32__
#endif
#endif

#ifdef __MINGW32__
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
  #include <openssl/rand.h>
  #include <openssl/err.h>
  #undef id

#include <Foundation/NSDebug.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSUserDefaults.h>

#include <GNUstepBase/GSFileHandle.h>
#include "GSPrivate.h"

#if defined(__MINGW32__)
#include <winsock2.h>
#else
#include <time.h>
#include <sys/time.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>
#endif /* __MINGW32__ */

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

static NSString*
sslError(int err)
{
  NSString	*str;

  SSL_load_error_strings();

  if (err == SSL_ERROR_SYSCALL)
    {
      NSError	*e = [NSError _last];

      str = [NSString stringWithFormat: @"Syscall error %d - %@",
        [e code], [e description]];
    }
  else if (err == SSL_ERROR_NONE)
    {
      str = @"No error: really helpful";
    }
  else
    {
      str = [NSString stringWithFormat: @"%s", ERR_reason_error_string(err)];

    }
  return str;
}


@interface	GSSSLHandle : GSFileHandle
{
  SSL_CTX	*ctx;
  SSL		*ssl;
  BOOL		connected;
}

- (BOOL) sslAccept;
- (BOOL) sslConnect;
- (void) sslDisconnect;
- (void) sslSetCertificate: (NSString*)certFile
		privateKey: (NSString*)privateKey
		 PEMpasswd: (NSString*)PEMpasswd;
@end

static BOOL	permitSSLv2 = NO;

@implementation	GSSSLHandle
+ (void) _defaultsChanged: (NSNotification*)n
{
  permitSSLv2
    = [[NSUserDefaults standardUserDefaults] boolForKey: @"GSPermitSSLv2"];
}

+ (void) initialize
{
  if (self == [GSSSLHandle class])
    {
      NSUserDefaults	*defs;

      SSL_library_init();

      /*
       * If there is no /dev/urandom for ssl to use, we must seed the
       * random number generator ourselves.
       */
      if (![[NSFileManager defaultManager] fileExistsAtPath: @"/dev/urandom"])
	{
	  const char	*inf;

	  inf = [[[NSProcessInfo processInfo] globallyUniqueString] UTF8String];
	  RAND_seed(inf, strlen(inf));
	}
      defs = [NSUserDefaults standardUserDefaults];
      permitSSLv2 = [defs boolForKey: @"GSPermitSSLv2"];
      [[NSNotificationCenter defaultCenter]
	addObserver: self
	   selector: @selector(_defaultsChanged:)
	       name: NSUserDefaultsDidChangeNotification
	     object: nil];
    }
}

- (void) closeFile
{
  [self sslDisconnect];
  [super closeFile];
}

- (void) finalize
{
  [self sslDisconnect];
  [super finalize];
}

- (int) read: (void*)buf length: (NSUInteger)len
{
  if (connected)
    {
      return SSL_read(ssl, buf, len);
    }
  return [super read: buf length: len];
}

- (BOOL) sslAccept
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
      ctx = SSL_CTX_new(SSLv23_server_method());
      if (permitSSLv2 == NO)
	{
          SSL_CTX_set_options(ctx, SSL_OP_NO_SSLv2);
	}
    }
  if (ssl == 0)
    {
      ssl = SSL_new(ctx);
    }
  /*
   * Set non-blocking so accept won't hang if remote end goes wrong.
   */
  [self setNonBlocking: YES];
  IF_NO_GC([self retain];)		// Don't get destroyed during runloop
  loop = [NSRunLoop currentRunLoop];
  ret = SSL_set_fd(ssl, descriptor);
  if (ret == 1)
    {
      [loop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]];
      if (ssl == 0)
	{
	  RELEASE(self);
	  return NO;
	}
      ret = SSL_accept(ssl);
    }
  if (ret != 1)
    {
      NSDate		*final;
      NSDate		*when;
      NSTimeInterval	last = 0.0;
      NSTimeInterval	limit = 0.1;

      final = [[NSDate alloc] initWithTimeIntervalSinceNow: 30.0];
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
	  if (ssl == 0)
	    {
	      RELEASE(when);
	      RELEASE(final);
	      RELEASE(self);
	      return NO;
	    }
	  ret = SSL_accept(ssl);
	  if (ret != 1)
	    {
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
	  if (err != SSL_ERROR_WANT_READ && err != SSL_ERROR_WANT_WRITE)
	    {
	      /*
	       * Some other error ... not just a timeout or disconnect
	       */
	      NSWarnLog(@"unable to accept SSL connection from %@:%@ - %@",
		address, service, sslError(err));
	    }
	  RELEASE(self);
	  return NO;
	}
    }
  connected = YES;
  RELEASE(self);
  return YES;
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
      if (permitSSLv2 == NO)
	{
          SSL_CTX_set_options(ctx, SSL_OP_NO_SSLv2);
	}
    }
  if (ssl == 0)
    {
      ssl = SSL_new(ctx);
    }
  IF_NO_GC([self retain];)		// Don't get destroyed during runloop
  /*
   * Set non-blocking so accept won't hang if remote end goes wrong.
   */
  [self setNonBlocking: YES];
  loop = [NSRunLoop currentRunLoop];
  ret = SSL_set_fd(ssl, descriptor);
  if (ret == 1)
    {
      [loop runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]];
      if (ssl == 0)
	{
	  RELEASE(self);
	  return NO;
	}
      ret = SSL_connect(ssl);
    }
  if (ret != 1)
    {
      NSDate		*final;
      NSDate		*when;
      NSTimeInterval	last = 0.0;
      NSTimeInterval	limit = 0.1;

      final = [[NSDate alloc] initWithTimeIntervalSinceNow: 30.0];
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
	  if (ssl == 0)
	    {
	      RELEASE(when);
	      RELEASE(final);
	      RELEASE(self);
	      return NO;
	    }
	  ret = SSL_connect(ssl);
	  if (ret != 1)
	    {
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
	  if (err != SSL_ERROR_WANT_READ && err != SSL_ERROR_WANT_WRITE)
	    {
	      /*
	       * Some other error ... not just a timeout or disconnect
	       */
	      NSLog(@"unable to make SSL connection to %@:%@ - %@",
		address, service, sslError(err));
	    }
	  RELEASE(self);
	  return NO;
	}
    }
  connected = YES;
  RELEASE(self);
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
  int	ret;

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
      ctx = SSL_CTX_new(SSLv23_method());
      if (permitSSLv2 == NO)
	{
          SSL_CTX_set_options(ctx, SSL_OP_NO_SSLv2);
	}
    }
  if ([PEMpasswd length] > 0)
    {
      SSL_CTX_set_default_passwd_cb_userdata(ctx,
	(char*)[PEMpasswd UTF8String]);
    }
  if ([certFile length] > 0)
    {
      ret = SSL_CTX_use_certificate_file(ctx, [certFile UTF8String],
	X509_FILETYPE_PEM);
      if (ret != 1)
	{
	  NSLog(@"Failed to set certificate file to %@ - %@",
	    certFile, sslError(ERR_get_error()));
	}
    }
  if ([privateKey length] > 0)
    {
      ret = SSL_CTX_use_PrivateKey_file(ctx, [privateKey UTF8String],
	X509_FILETYPE_PEM);
      if (ret != 1)
	{
	  NSLog(@"Failed to set private key file to %@ - %@",
	    privateKey, sslError(ERR_get_error()));
	}
    }
}

- (int) write: (const void*)buf length: (NSUInteger)len
{
  if (connected)
    {
      return SSL_write(ssl, buf, len);
    }
  return [super write: buf length: len];
}

@end


/** Implementation for GSSocketStream for GNUStep
   Copyright (C) 2006-2008 Free Software Foundation, Inc.

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

#include "config.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSByteOrder.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSHost.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSValue.h>

#import "GSStream.h"
#import "GSSocketStream.h"
#import "GSPrivate.h"

#if     defined(HAVE_GNUTLS)
#include <gnutls/gnutls.h>
#include <gcrypt.h>

/* Set up locking callbacks for gcrypt so that it will be thread-safe.
 */
static int gcry_mutex_init (void **priv)
{
  NSLock        *lock = [NSLock new];
  *priv = (void*)lock;
  return 0;
}
static int gcry_mutex_destroy (void **lock)
{
  [((NSLock*)*lock) release];
  return 0;
}
static int gcry_mutex_lock (void **lock)
{
  [((NSLock*)*lock) lock];
  return 0;
}
static int gcry_mutex_unlock (void **lock)
{
  [((NSLock*)*lock) unlock];
  return 0;
}
static struct gcry_thread_cbs gcry_threads_other = {
  GCRY_THREAD_OPTION_DEFAULT,
  NULL,
  gcry_mutex_init,
  gcry_mutex_destroy,
  gcry_mutex_lock,
  gcry_mutex_unlock
};
#endif


@interface      GSTLS : NSObject
{
  GSSocketInputStream   *input;         // Not retained
  GSSocketOutputStream  *output;        // Not retained
  BOOL                  initialised;
  BOOL                  handshake;
  BOOL                  active;
#if     defined(HAVE_GNUTLS)
@public
  gnutls_session_t      session;
  gnutls_certificate_credentials_t      certcred;
#endif
}
- (id) initWithInput: (GSSocketInputStream*)i
              output: (GSSocketOutputStream*)o;
- (GSSocketInputStream*) input;
- (GSSocketOutputStream*) output;

- (void) bye;           /* Close down the TLS session.  */
- (BOOL) handshake;     /* A handshake/hello is in progress. */
- (void) hello;         /* Start up the TLS session handshake.    */
- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len;
- (void) stream: (NSStream*)stream handleEvent: (NSStreamEvent)event;
- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len;
@end

#if     defined(HAVE_GNUTLS)

/* Callback to allow the TLS code to pull data from the remote system.
 * If the operation fails, this sets the error number.
 */
static ssize_t
GSTLSPull(gnutls_transport_ptr_t handle, void *buffer, size_t len)
{
  ssize_t       result;
  GSTLS         *tls = (GSTLS*)handle;
  
  result = [[tls input] _read: buffer maxLength: len];
  if (result < 0)
    {
      int       e;

      if ([[tls input] streamStatus] == NSStreamStatusError)
        {
          e = [[[(GSTLS*)handle input] streamError] code];
        }
      else
        {
          e = EAGAIN;
        }
      gnutls_transport_set_errno (tls->session, e);
    }
  return result;
}

/* Callback to allow the TLS code to push data to the remote system.
 * If the operation fails, this sets the error number.
 */
static ssize_t
GSTLSPush(gnutls_transport_ptr_t handle, const void *buffer, size_t len)
{
  ssize_t       result;
  GSTLS         *tls = (GSTLS*)handle;
  
  result = [[tls output] _write: buffer maxLength: len];
  if (result < 0)
    {
      int       e;

      if ([[tls output] streamStatus] == NSStreamStatusError)
        {
          e = [[[tls output] streamError] code];
        }
      else
        {
          e = EAGAIN;
        }
      gnutls_transport_set_errno (tls->session, e);
    }
  return result;
}

static void
GSTLSLog(int level, const char *msg)
{
  NSLog(@"%s", msg);
}

#endif  /* HAVE_GNUTLS */


@implementation GSTLS
#if     defined(HAVE_GNUTLS)
static gnutls_anon_client_credentials_t anoncred;
#endif  /* HAVE_GNUTLS */

+ (void) initialize
{
#if     defined(HAVE_GNUTLS)
  static BOOL   beenHere = NO;

  if (beenHere == NO)
    {
      beenHere = YES;

      /* Make gcrypt thread-safe
       */
      gcry_control (GCRYCTL_SET_THREAD_CBS, &gcry_threads_other);
      /* Initialise gnutls
       */
      gnutls_global_init ();
      /* Allocate global credential information for anonymous tls
       */
      gnutls_anon_allocate_client_credentials (&anoncred);
      /* Enable gnutls logging via NSLog
       */
      gnutls_global_set_log_function (GSTLSLog);
//      gnutls_global_set_log_level (11);
    }
#endif  /* HAVE_GNUTLS */
}

- (void) bye
{
#if     defined(HAVE_GNUTLS)
  if (active == YES || handshake == YES)
    {
      active = NO;
      handshake = NO;
      gnutls_bye (session, GNUTLS_SHUT_RDWR);
    }
#endif  /* HAVE_GNUTLS */
}

- (void) dealloc
{
  [self bye];
#if     defined(HAVE_GNUTLS)
  gnutls_db_remove_session (session);
  gnutls_deinit (session);
  gnutls_certificate_free_credentials (&certcred);
#endif  /* HAVE_GNUTLS */
  [super dealloc];
}

- (BOOL) handshake
{
  return handshake;
}

- (void) hello
{
  if (active == NO)
    {
#if     defined(HAVE_GNUTLS)
      int   ret;

      if (handshake == NO)
        {
          /* Set flag to say we are now doing a handshake.
           */
          handshake = YES;
        }
      ret = gnutls_handshake (session);
      if (ret < 0)
        {
          NSDebugMLog(@"NSThread", @"Handshake status %d", ret);
        }
      else
        {
          handshake = NO;       // Handshake is now complete.
          active = YES;         // The TLS session is now active.
        }

#endif  /* HAVE_GNUTLS */
    }
}

- (id) initWithInput: (GSSocketInputStream*)i
              output: (GSSocketOutputStream*)o
{
#if     defined(HAVE_GNUTLS)
  NSString      *proto = [i propertyForKey: NSStreamSocketSecurityLevelKey];

  if ([[o propertyForKey: NSStreamSocketSecurityLevelKey] isEqual: proto] == NO)
    {
      DESTROY(self);
      return nil;
    }
  if ([proto isEqualToString: NSStreamSocketSecurityLevelNone] == YES)
    {
      proto = NSStreamSocketSecurityLevelNone;
      DESTROY(self);
      return nil;
    }
  else if ([proto isEqualToString: NSStreamSocketSecurityLevelSSLv2] == YES)
    {
      proto = NSStreamSocketSecurityLevelSSLv2;
      GSOnceMLog(@"NSStreamSocketSecurityLevelTLSv1 is insecure ..."
        @" not implemented");
      DESTROY(self);
      return nil;
    }
  else if ([proto isEqualToString: NSStreamSocketSecurityLevelSSLv3] == YES)
    {
      proto = NSStreamSocketSecurityLevelSSLv3;
    }
  else if ([proto isEqualToString: NSStreamSocketSecurityLevelTLSv1] == YES)
    {
      proto = NSStreamSocketSecurityLevelTLSv1;
    }
  else
    {
      proto = NSStreamSocketSecurityLevelNegotiatedSSL;
    }

  input = i;
  output = o;
  initialised = YES;
  /* Configure this session to support certificate based
   * operation.
   */
  gnutls_certificate_allocate_credentials (&certcred);

  /* FIXME ... should get the trusted authority certificates
   * from somewhere sensible to validate the remote end!
   */
  gnutls_certificate_set_x509_trust_file
    (certcred, "ca.pem", GNUTLS_X509_FMT_PEM);

  /* Initialise session and set default priorities foir key exchange.
   */
  gnutls_init (&session, GNUTLS_CLIENT);
  gnutls_set_default_priority (session);

  if ([proto isEqualToString: NSStreamSocketSecurityLevelTLSv1] == YES)
    {
      const int proto_prio[4] = {
        GNUTLS_TLS1_2,
        GNUTLS_TLS1_1,
        GNUTLS_TLS1_0,
        0 };
      gnutls_protocol_set_priority (session, proto_prio);
    }
  if ([proto isEqualToString: NSStreamSocketSecurityLevelSSLv3] == YES)
    {
      const int proto_prio[2] = {
        GNUTLS_SSL3,
        0 };
      gnutls_protocol_set_priority (session, proto_prio);
    }

/*
 {
    const int kx_prio[] = {
      GNUTLS_KX_RSA,
      GNUTLS_KX_RSA_EXPORT,
      GNUTLS_KX_DHE_RSA,
      GNUTLS_KX_DHE_DSS,
      GNUTLS_KX_ANON_DH,
      0 };
    gnutls_kx_set_priority (session, kx_prio);
    gnutls_credentials_set (session, GNUTLS_CRD_ANON, anoncred);
  }
 */ 

  /* Set certificate credentials for this session.
   */
  gnutls_credentials_set (session, GNUTLS_CRD_CERTIFICATE, certcred);
  
  /* Set transport layer to use our low level stream code.
   */
  gnutls_transport_set_lowat (session, 0);
  gnutls_transport_set_pull_function (session, GSTLSPull);
  gnutls_transport_set_push_function (session, GSTLSPush);
  gnutls_transport_set_ptr (session, (gnutls_transport_ptr_t)self);

#else
  DESTROY(self);
#endif  /* HAVE_GNUTLS */
  return self;
}

- (GSSocketInputStream*) input
{
  return input;
}

- (GSSocketOutputStream*) output
{
  return output;
}

- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len
{
#if     defined(HAVE_GNUTLS)
  return gnutls_record_recv (session, buffer, len);
#else
  return 0;
#endif  /* HAVE_GNUTLS */
}

- (void) stream: (NSStream*)stream handleEvent: (NSStreamEvent)event
{
//NSLog(@"GSTLS got %d on %p", event, stream);

  if (handshake == YES)
    {
      [self hello]; /* try to complete the handshake */
      if (handshake == NO)
        {
          [input _sendEvent: NSStreamEventOpenCompleted];
          [output _sendEvent: NSStreamEventOpenCompleted];
        }
    }
}

- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len
{
#if     defined(HAVE_GNUTLS)
  return gnutls_record_send (session, buffer, len);
#else
  return 0;
#endif  /* HAVE_GNUTLS */
}

@end


/*
 * States for socks connection negotiation
 */
static NSString * const GSSOCKSOfferAuth = @"GSSOCKSOfferAuth";
static NSString * const GSSOCKSRecvAuth = @"GSSOCKSRecvAuth";
static NSString * const GSSOCKSSendAuth = @"GSSOCKSSendAuth";
static NSString * const GSSOCKSAckAuth = @"GSSOCKSAckAuth";
static NSString * const GSSOCKSSendConn = @"GSSOCKSSendConn";
static NSString * const GSSOCKSAckConn = @"GSSOCKSAckConn";

@interface	GSSOCKS : NSObject
{
  NSString		*state;
  NSString		*addr;
  int			port;
  int			roffset;
  int			woffset;
  int			rwant;
  unsigned char		rbuffer[128];
  NSInputStream		*istream;
  NSOutputStream	*ostream;
}
- (NSString*) addr;
- (id) initToAddr: (NSString*)_addr port: (int)_port;
- (int) port;
- (NSString*) stream: (NSStream*)stream SOCKSEvent: (NSStreamEvent)event;
@end

@implementation	GSSOCKS
- (NSString*) addr
{
  return addr;
}

- (id) initToAddr: (NSString*)_addr port: (int)_port
{
  ASSIGNCOPY(addr, _addr);
  port = _port;
  state = GSSOCKSOfferAuth;
  return self;
}

- (int) port
{
  return port;
}

- (NSString*) stream: (NSStream*)stream SOCKSEvent: (NSStreamEvent)event
{
  NSString		*error = nil;
  NSDictionary		*conf;
  NSString		*user;
  NSString		*pass;

  if (event == NSStreamEventErrorOccurred
    || [stream streamStatus] == NSStreamStatusError
    || [stream streamStatus] == NSStreamStatusClosed)
    {
      return @"SOCKS errur during negotiation";
    }

  conf = [stream propertyForKey: NSStreamSOCKSProxyConfigurationKey];
  user = [conf objectForKey: NSStreamSOCKSProxyUserKey];
  pass = [conf objectForKey: NSStreamSOCKSProxyPasswordKey];
  if ([[conf objectForKey: NSStreamSOCKSProxyVersionKey]
    isEqual: NSStreamSOCKSProxyVersion4] == YES)
    {
    }
  else
    {
      again:

      if (state == GSSOCKSOfferAuth)
	{
	  int		result;
	  int		want;
	  unsigned char	buf[4];

	  /*
	   * Authorisation record is at least three bytes -
	   *   socks version (5)
	   *   authorisation method bytes to follow (1)
	   *   say we do no authorisation (0)
	   *   say we do user/pass authorisation (2)
	   */
	  buf[0] = 5;
	  if (user && pass)
	    {
	      buf[1] = 2;
	      buf[2] = 2;
	      buf[3] = 0;
	      want = 4;
	    }
	  else
	    {
	      buf[1] = 1;
	      buf[2] = 0;
	      want = 3;
	    }

	  result = [ostream write: buf + woffset maxLength: 4 - woffset];
	  if (result == 0)
	    {
	      error = @"end-of-file during SOCKS negotiation";
	    }
	  else if (result > 0)
	    {
	      woffset += result;
	      if (woffset == want)
		{
		  woffset = 0;
		  state = GSSOCKSRecvAuth;
		  goto again;
		}
	    }
	}
      else if (state == GSSOCKSRecvAuth)
	{
	  int	result;

	  result = [istream read: rbuffer + roffset maxLength: 2 - roffset];
	  if (result == 0)
	    {
	      error = @"SOCKS end-of-file during negotiation";
	    }
	  else if (result > 0)
	    {
	      roffset += result;
	      if (roffset == 2)
		{
		  roffset = 0;
		  if (rbuffer[0] != 5)
		    {
		      error = @"SOCKS authorisation response had wrong version";
		    }
		  else if (rbuffer[1] == 0)
		    {
		      state = GSSOCKSSendConn;
		      goto again;
		    }
		  else if (rbuffer[1] == 2)
		    {
		      state = GSSOCKSSendAuth;
		      goto again;
		    }
		  else
		    {
		      error = @"SOCKS authorisation response had wrong method";
		    }
		}
	    }
	}
      else if (state == GSSOCKSSendAuth)
	{
	  NSData	*u = [user dataUsingEncoding: NSUTF8StringEncoding];
	  unsigned	ul = [u length];
	  NSData	*p = [pass dataUsingEncoding: NSUTF8StringEncoding];
	  unsigned	pl = [p length];

	  if (ul < 1 || ul > 255)
	    {
	      error = @"NSStreamSOCKSProxyUserKey value too long";
	    }
	  else if (ul < 1 || ul > 255)
	    {
	      error = @"NSStreamSOCKSProxyPasswordKey value too long";
	    }
	  else
	    {
	      int		want = ul + pl + 3;
	      unsigned char	buf[want];
	      int		result;

	      buf[0] = 5;
	      buf[1] = ul;
	      memcpy(buf + 2, [u bytes], ul);
	      buf[ul + 2] = pl;
	      memcpy(buf + ul + 3, [p bytes], pl);
	      result = [ostream write: buf + woffset maxLength: want - woffset];
	      if (result == 0)
		{
		  error = @"SOCKS end-of-file during negotiation";
		}
	      else if (result > 0)
		{
		  woffset += result;
		  if (woffset == want)
		    {
		      state = GSSOCKSAckAuth;
		      goto again;
		    }
		}
	    }
	}
      else if (state == GSSOCKSAckAuth)
	{
	  int	result;

	  result = [istream read: rbuffer + roffset maxLength: 2 - roffset];
	  if (result == 0)
	    {
	      error = @"SOCKS end-of-file during negotiation";
	    }
	  else if (result > 0)
	    {
	      roffset += result;
	      if (roffset == 2)
		{
		  roffset = 0;
		  if (rbuffer[0] != 5)
		    {
		      error = @"SOCKS authorisation response had wrong version";
		    }
		  else if (rbuffer[1] == 0)
		    {
		      state = GSSOCKSSendConn;
		      goto again;
		    }
		  else if (rbuffer[1] == 2)
		    {
		      error = @"SOCKS authorisation failed";
		    }
		}
	    }
	}
      else if (state == GSSOCKSSendConn)
	{
	  unsigned char	buf[10];
	  int		want = 10;
	  int		result;
	  const char	*ptr;

	  /*
	   * Connect command is ten bytes -
	   *   socks version
	   *   connect command
	   *   reserved byte
	   *   address type
	   *   address 4 bytes (big endian)
	   *   port 2 bytes (big endian)
	   */
	  buf[0] = 5;	// Socks version number
	  buf[1] = 1;	// Connect command
	  buf[2] = 0;	// Reserved
	  buf[3] = 1;	// Address type (IPV4)
	  ptr = [addr lossyCString];
	  buf[4] = atoi(ptr);
	  while (isdigit(*ptr))
	    ptr++;
	  ptr++;
	  buf[5] = atoi(ptr);
	  while (isdigit(*ptr))
	    ptr++;
	  ptr++;
	  buf[6] = atoi(ptr);
	  while (isdigit(*ptr))
	    ptr++;
	  ptr++;
	  buf[7] = atoi(ptr);
	  buf[8] = ((port & 0xff00) >> 8);
	  buf[9] = (port & 0xff);

	  result = [ostream write: buf + woffset maxLength: want - woffset];
	  if (result == 0)
	    {
	      error = @"SOCKS end-of-file during negotiation";
	    }
	  else if (result > 0)
	    {
	      woffset += result;
	      if (woffset == want)
		{
		  rwant = 5;
		  state = GSSOCKSAckConn;
		  goto again;
		}
	    }
	}
      else if (state == GSSOCKSAckConn)
	{
	  int	result;

	  result = [istream read: rbuffer + roffset maxLength: rwant - roffset];
	  if (result == 0)
	    {
	      error = @"SOCKS end-of-file during negotiation";
	    }
	  else if (result > 0)
	    {
	      roffset += result;
	      if (roffset == rwant)
		{
		  if (rbuffer[0] != 5)
		    {
		      error = @"connect response from SOCKS had wrong version";
		    }
		  else if (rbuffer[1] != 0)
		    {
		      switch (rbuffer[1])
			{
			  case 1:
			    error = @"SOCKS server general failure";
			    break;
			  case 2:
			    error = @"SOCKS server says permission denied";
			    break;
			  case 3:
			    error = @"SOCKS server says network unreachable";
			    break;
			  case 4:
			    error = @"SOCKS server says host unreachable";
			    break;
			  case 5:
			    error = @"SOCKS server says connection refused";
			    break;
			  case 6:
			    error = @"SOCKS server says connection timed out";
			    break;
			  case 7:
			    error = @"SOCKS server says command not supported";
			    break;
			  case 8:
			    error = @"SOCKS server says address not supported";
			    break;
			  default:
			    error = @"connect response from SOCKS was failure";
			    break;
			}
		    }
		  else if (rbuffer[3] == 1)
		    {
		      rwant = 10;		// Fixed size (IPV4) address
		    }
		  else if (rbuffer[3] == 3)
		    {
		      rwant = 7 + rbuffer[4];	// Domain name leading length
		    }
		  else if (rbuffer[3] == 4)
		    {
		      rwant = 22;		// Fixed size (IPV6) address
		    }
		  else
		    {
		      error = @"SOCKS server returned unknown address type";
		    }
		  if (error == nil)
		    {
		      if (roffset < rwant)
			{
			  goto again;	// Need address/port bytes
			}
		      else
			{
			  NSString	*a;

			  error = @"";	// success
			  if (rbuffer[3] == 1)
			    {
			      a = [NSString stringWithFormat: @"%d.%d.%d.%d",
			        rbuffer[4], rbuffer[5], rbuffer[6], rbuffer[7]];
			    }
			  else if (rbuffer[3] == 3)
			    {
			      rbuffer[rwant] = '\0';
			      a = [NSString stringWithUTF8String:
			        (const char*)rbuffer];
			    }
			  else
			    {
			      unsigned char	buf[40];
			      int		i = 4;
			      int		j = 0;

			      while (i < rwant)
			        {
				  int	val = rbuffer[i++] * 256 + rbuffer[i++];

				  if (i > 4)
				    {
				      buf[j++] = ':';
				    }
				  sprintf((char*)&buf[j], "%04x", val);
				  j += 4;
				}
			      a = [NSString stringWithUTF8String:
			        (const char*)buf];
			    }
			  ASSIGN(addr, a);
			  port =  rbuffer[rwant-1] * 256 * rbuffer[rwant-2];
			}
		    }
		}
	    }
	}
    }

  return error;
}

@end


static inline BOOL
socketError(int result)
{
#if	defined(__MINGW32__)
  return (result == SOCKET_ERROR) ? YES : NO;
#else
  return (result < 0) ? YES : NO;
#endif
}

static inline BOOL
socketWouldBlock()
{
#if	defined(__MINGW32__)
  int   e = WSAGetLastError();
  return (e == WSAEWOULDBLOCK || e == WSAEINPROGRESS) ? YES : NO;
#else
  return (errno == EWOULDBLOCK || errno == EINPROGRESS) ? YES : NO;
#endif
}


static void
setNonBlocking(SOCKET fd)
{
#if	defined(__MINGW32__)
  unsigned long dummy = 1;

  if (ioctlsocket(fd, FIONBIO, &dummy) == SOCKET_ERROR)
    {
      NSLog(@"unable to set non-blocking mode - %@", [NSError _last]);
    }
#else
  int flags = fcntl(fd, F_GETFL, 0);

  if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0)
    {
      NSLog(@"unable to set non-blocking mode - %@",
        [NSError _last]);
    }
#endif
}

@implementation GSSocketStream

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  [_sibling _setSibling: nil];
  _sibling = nil;
  DESTROY(_tls);
  [super dealloc];
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      // so that unopened access will fail
      _sibling = nil;
      _closing = NO;
      _passive = NO;
#if	defined(__MINGW32__)
      _loopID = WSA_INVALID_EVENT;
      _sock = INVALID_SOCKET;
#else
      _loopID = (void*)(intptr_t)-1;
      _sock = -1;
#endif
      _tls = nil;
    }
  return self;
}

- (struct sockaddr*) _peerAddr
{
  [self subclassResponsibility: _cmd];
  return NULL;
}

- (int) _read: (uint8_t *)buffer maxLength: (unsigned int)len
{
  [self subclassResponsibility: _cmd];
  return -1;
}

- (void) _sendEvent: (NSStreamEvent)event
{
  /* If the receiver has a TLS handshake in progress,
   * we must send events to the TLS handler rather than
   * the stream delegate.
   */
  if (_tls != nil && [_tls handshake] == YES)
    {
      id        del = _delegate;
      BOOL      val = _delegateValid;

      _delegate = _tls;
      _delegateValid = YES;
      [super _sendEvent: event];
      _delegate = del;
      _delegateValid = val;
    }
  else
    {
      [super _sendEvent: event];
    }
}

- (void) _setLoopID: (void *)ref
{
#if	!defined(__MINGW32__)
  _sock = (SOCKET)(intptr_t)ref;        // On gnu/linux _sock is _loopID
#endif
  _loopID = ref;
}

- (void) _setClosing: (BOOL)closing
{
  _closing = closing;
}

- (void) _setPassive: (BOOL)passive
{
  _passive = passive;
}

- (void) _setSibling: (GSSocketStream*)sibling
{
  _sibling = sibling;
}

- (void) _setSock: (SOCKET)sock
{
  setNonBlocking(sock);
  _sock = sock;

  /* As well as recording the socket, we set up the stream for monitoring it.
   * On unix style systems we set the socket descriptor as the _loopID to be
   * monitored, and on mswindows systems we create an event object to be
   * monitored (the socket events are assoociated with this object later).
   */
#if	defined(__MINGW32__)
  _loopID = CreateEvent(NULL, NO, NO, NULL);
#else
  _loopID = (void*)(intptr_t)sock;      // On gnu/linux _sock is _loopID
#endif
}

- (void) _setTLS: (GSTLS*)t
{
  ASSIGN(_tls, t);
}

- (SOCKET) _sock
{
  return _sock;
}

- (socklen_t) _sockLen
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (int) _write: (const uint8_t *)buffer maxLength: (unsigned int)len
{
  [self subclassResponsibility: _cmd];
  return -1;
}

@end


@implementation GSSocketInputStream

+ (void) initialize
{
  if (self == [GSSocketInputStream class])
    {
      GSObjCAddClassBehavior(self, [GSSocketStream class]);
    }
}

- (void) open
{
  // could be opened because of sibling
  if ([self _isOpened])
    return;
  if (_passive || (_sibling && [_sibling _isOpened]))
    goto open_ok;
  // check sibling status, avoid double connect
  if (_sibling && [_sibling streamStatus] == NSStreamStatusOpening)
    {
      [self _setStatus: NSStreamStatusOpening];
      return;
    }
  else
    {
      int result;

      result = connect([self _sock], [self _peerAddr], [self _sockLen]);
      if (socketError(result))
        {
          if (!socketWouldBlock())
            {
              [self _recordError];
              return;
            }
          /*
           * Need to set the status first, so that the run loop can tell
           * it needs to add the stream as waiting on writable, as an
           * indication of opened
           */
          [self _setStatus: NSStreamStatusOpening];
#if	defined(__MINGW32__)
          WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
#endif
	  if (NSCountMapTable(_loops) > 0)
	    {
	      [self _schedule];
	      return;
	    }
          else
            {
              NSRunLoop *r;
              NSDate    *d;

              /* The stream was not scheduled in any run loop, so we
               * implement a blocking connect by running in the default
               * run loop mode.
               */
              r = [NSRunLoop currentRunLoop];
              d = [NSDate distantFuture];
              [r addStream: self mode: NSDefaultRunLoopMode];
              while ([r runMode: NSDefaultRunLoopMode beforeDate: d] == YES)
                {
                  if (_currentStatus != NSStreamStatusOpening)
                    {
                      break;
                    }
                }
              [r removeStream: self mode: NSDefaultRunLoopMode];
              return;
            }
        }
    }

 open_ok:
#if	defined(__MINGW32__)
  WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
#endif
  [super open];
}

- (void) close
{
  if (_currentStatus == NSStreamStatusNotOpen)
    {
      NSDebugMLog(@"Attempt to close unopened stream %@", self);
      return;
    }
  if (_currentStatus == NSStreamStatusClosed)
    {
      NSDebugMLog(@"Attempt to close already closed stream %@", self);
      return;
    }
  [_tls bye];
#if	defined(__MINGW32__)
  if (_sibling && [_sibling streamStatus] != NSStreamStatusClosed)
    {
      /*
       * Windows only permits a single event to be associated with a socket
       * at any time, but the runloop system only allows an event handle to
       * be added to the loop once, and we have two streams for each socket.
       * So we use two events, one for each stream, and when one stream is
       * closed, we must call WSAEventSelect to ensure that the event handle
       * of the sibling is used to signal events from now on.
       */
      WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
      shutdown(_sock, SD_RECEIVE);
      WSAEventSelect(_sock, [_sibling _loopID], FD_ALL_EVENTS);
    }
  else
    {
      closesocket(_sock);
    }
  WSACloseEvent(_loopID);
  [super close];
  _sock = INVALID_SOCKET;
  _loopID = WSA_INVALID_EVENT;
#else
  // read shutdown is ignored, because the other side may shutdown first.
  if (!_sibling || [_sibling streamStatus] == NSStreamStatusClosed)
    close((intptr_t)_loopID);
  else
    shutdown((intptr_t)_loopID, SHUT_RD);
  [super close];
  _sock = -1;
  _loopID = (void*)(intptr_t)-1;
#endif
}

- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len
{
  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"zero byte read requested"];
    }

  if (_tls == nil)
    return [self _read: buffer maxLength: len];
  else
    return [_tls read: buffer maxLength: len];
}

- (int) _read: (uint8_t *)buffer maxLength: (unsigned int)len
{
  int readLen;

  _events &= ~NSStreamEventHasBytesAvailable;

  if ([self streamStatus] == NSStreamStatusClosed)
    {
      return 0;
    }
  if ([self streamStatus] == NSStreamStatusAtEnd)
    {
      readLen = 0;
    }
  else
    {
#if	defined(__MINGW32__)
      readLen = recv([self _sock], buffer, len, 0);
#else
      readLen = read([self _sock], buffer, len);
#endif
    }
  if (socketError(readLen))
    {
      if (_closing == YES)
        {
          /* If a read fails on a closing socket,
           * we have reached the end of all data sent by
           * the remote end before it shut down.
           */
          [self _setClosing: NO];
          [self _setStatus: NSStreamStatusAtEnd];
          [self _sendEvent: NSStreamEventEndEncountered];
          readLen = 0;
        }
      else
        {
          if (socketWouldBlock())
            {
              /* We need an event from the operating system
               * to tell us we can start reading again.
               */
              [self _setStatus: NSStreamStatusReading];
            }
          else
            {
              [self _recordError];
            }
          readLen = -1;
        }
    }
  else if (readLen == 0)
    {
      [self _setStatus: NSStreamStatusAtEnd];
      [self _sendEvent: NSStreamEventEndEncountered];
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
    }
  return readLen;
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (unsigned int *)len
{
  return NO;
}

- (void) _dispatch
{
#if	defined(__MINGW32__)
  AUTORELEASE(RETAIN(self));
  /*
   * Windows only permits a single event to be associated with a socket
   * at any time, but the runloop system only allows an event handle to
   * be added to the loop once, and we have two streams for each socket.
   * So we use two events, one for each stream, and the _dispatch method
   * must handle things for both streams.
   */
  if ([self streamStatus] == NSStreamStatusClosed)
    {
      /*
       * It is possible the stream is closed yet recieving event because
       * of not closed sibling
       */
      NSAssert([_sibling streamStatus] != NSStreamStatusClosed, 
	@"Received event for closed stream");
      [_sibling _dispatch];
    }
  else
    {
      WSANETWORKEVENTS events;
      int error = 0;
      int getReturn = -1;

      if (WSAEnumNetworkEvents(_sock, _loopID, &events) == SOCKET_ERROR)
	{
	  error = WSAGetLastError();
	}
// else NSLog(@"EVENTS 0x%x on %p", events.lNetworkEvents, self);

      if ([self streamStatus] == NSStreamStatusOpening)
	{
	  [self _unschedule];
	  if (error == 0)
	    {
	      unsigned len = sizeof(error);

	      getReturn = getsockopt(_sock, SOL_SOCKET, SO_ERROR,
		(char*)&error, &len);
	    }

	  if (getReturn >= 0 && error == 0
	    && (events.lNetworkEvents & FD_CONNECT))
	    { // finish up the opening
	      _passive = YES;
	      [self open];
	      // notify sibling
	      if (_sibling)
		{
		  [_sibling open];
		  [_sibling _sendEvent: NSStreamEventOpenCompleted];
		}
	      [self _sendEvent: NSStreamEventOpenCompleted];
	    }
	}

      if (error != 0)
	{
	  errno = error;
	  [self _recordError];
	  [_sibling _recordError];
	  [self _sendEvent: NSStreamEventErrorOccurred];
	  [_sibling _sendEvent: NSStreamEventErrorOccurred];
	}
      else
	{
	  if (events.lNetworkEvents & FD_WRITE)
	    {
	      NSAssert([_sibling _isOpened], NSInternalInconsistencyException);
	      /* Clear NSStreamStatusWriting if it was set */
	      [_sibling _setStatus: NSStreamStatusOpen];
	    }

	  /* On winsock a socket is always writable unless it has had
	   * failure/closure or a write blocked and we have not been
	   * signalled again.
	   */
	  while ([_sibling _unhandledData] == NO
	    && [_sibling hasSpaceAvailable])
	    {
	      [_sibling _sendEvent: NSStreamEventHasSpaceAvailable];
	    }

	  if (events.lNetworkEvents & FD_READ)
	    {
	      [self _setStatus: NSStreamStatusOpen];
	      while ([self hasBytesAvailable]
		&& [self _unhandledData] == NO)
		{
	          [self _sendEvent: NSStreamEventHasBytesAvailable];
		}
	    }

	  if (events.lNetworkEvents & FD_CLOSE)
	    {
	      [self _setClosing: YES];
	      [_sibling _setClosing: YES];
	      while ([self hasBytesAvailable]
		&& [self _unhandledData] == NO)
		{
		  [self _sendEvent: NSStreamEventHasBytesAvailable];
		}
	    }
	  if (events.lNetworkEvents == 0)
	    {
	      [self _sendEvent: NSStreamEventHasBytesAvailable];
	    }
	}
    }
#else
  NSStreamEvent myEvent;

  if ([self streamStatus] == NSStreamStatusOpening)
    {
      int error;
      int result;
      socklen_t len = sizeof(error);

      AUTORELEASE(RETAIN(self));
      [self _unschedule];
      result = getsockopt([self _sock], SOL_SOCKET, SO_ERROR, &error, &len);

      if (result >= 0 && !error)
        { // finish up the opening
          myEvent = NSStreamEventOpenCompleted;
          _passive = YES;
          [self open];
          // notify sibling
          [_sibling open];
          [_sibling _sendEvent: myEvent];
        }
      else // must be an error
        {
          if (error)
            errno = error;
          [self _recordError];
          myEvent = NSStreamEventErrorOccurred;
          [_sibling _recordError];
          [_sibling _sendEvent: myEvent];
        }
    }
  else if ([self streamStatus] == NSStreamStatusAtEnd)
    {
      myEvent = NSStreamEventEndEncountered;
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
      myEvent = NSStreamEventHasBytesAvailable;
    }
  [self _sendEvent: myEvent];
#endif
}

#if	defined(__MINGW32__)
- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  *trigger = YES;
  return YES;
}
#endif

@end


@implementation GSSocketOutputStream

+ (void) initialize
{
  if (self == [GSSocketOutputStream class])
    {
      GSObjCAddClassBehavior(self, [GSSocketStream class]);
    }
}

- (int) _write: (const uint8_t *)buffer maxLength: (unsigned int)len
{
  int writeLen;

  _events &= ~NSStreamEventHasSpaceAvailable;

  if ([self streamStatus] == NSStreamStatusClosed)
    {
      return 0;
    }
  if ([self streamStatus] == NSStreamStatusAtEnd)
    {
      [self _sendEvent: NSStreamEventEndEncountered];
      return 0;
    }

#if	defined(__MINGW32__)
  writeLen = send([self _sock], buffer, len, 0);
#else
  writeLen = write([self _sock], buffer, len);
#endif

  if (socketError(writeLen))
    {
      if (_closing == YES)
        {
          /* If a write fails on a closing socket,
           * we know the other end is no longer reading.
           */
          [self _setClosing: NO];
          [self _setStatus: NSStreamStatusAtEnd];
          [self _sendEvent: NSStreamEventEndEncountered];
          writeLen = 0;
        }
      else
        {
          if (socketWouldBlock())
            {
              /* We need an event from the operating system
               * to tell us we can start writing again.
               */
              [self _setStatus: NSStreamStatusWriting];
            }
          else
            {
              [self _recordError];
            }
          writeLen = -1;
        }
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
    }
  return writeLen;
}

- (void) open
{
  NSString      *tls;

  // could be opened because of sibling
  if ([self _isOpened])
    return;
  if (_passive || (_sibling && [_sibling _isOpened]))
    goto open_ok;
  // check sibling status, avoid double connect
  if (_sibling && [_sibling streamStatus] == NSStreamStatusOpening)
    {
      [self _setStatus: NSStreamStatusOpening];
      return;
    }
  else
    {
      int result;
      
      result = connect([self _sock], [self _peerAddr], [self _sockLen]);
      if (socketError(result))
        {
          if (!socketWouldBlock())
            {
              [self _recordError];
              return;
            }
          /*
           * Need to set the status first, so that the run loop can tell
           * it needs to add the stream as waiting on writable, as an
           * indication of opened
           */
          [self _setStatus: NSStreamStatusOpening];
#if	defined(__MINGW32__)
          WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
#endif
	  if (NSCountMapTable(_loops) > 0)
	    {
	      [self _schedule];
	      return;
	    }
          else
            {
              NSRunLoop *r;
              NSDate    *d;

              /* The stream was not scheduled in any run loop, so we
               * implement a blocking connect by running in the default
               * run loop mode.
               */
              r = [NSRunLoop currentRunLoop];
              d = [NSDate distantFuture];
              [r addStream: self mode: NSDefaultRunLoopMode];
              while ([r runMode: NSDefaultRunLoopMode beforeDate: d] == YES)
                {
                  if (_currentStatus != NSStreamStatusOpening)
                    {
                      break;
                    }
                }
              [r removeStream: self mode: NSDefaultRunLoopMode];
              return;
            }
        }
    }

 open_ok: 
#if	defined(__MINGW32__)
  WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
#endif
  [super open];
  tls = [self propertyForKey: NSStreamSocketSecurityLevelKey];
  if (tls == nil && _sibling != nil)
    {
      tls = [_sibling propertyForKey: NSStreamSocketSecurityLevelKey];
      if (tls != nil)
        {
          [self setProperty: tls forKey: NSStreamSocketSecurityLevelKey];
        }
    }
  if (tls != nil)
    {
      GSTLS     *t;

      t = [[GSTLS alloc] initWithInput: _sibling output: self];
      [_sibling _setTLS: t];
      [self _setTLS: t];
      RELEASE(t);
      [_tls hello];
    }
}


- (void) close
{
  if (_currentStatus == NSStreamStatusNotOpen)
    {
      NSDebugMLog(@"Attempt to close unopened stream %@", self);
      return;
    }
  if (_currentStatus == NSStreamStatusClosed)
    {
      NSDebugMLog(@"Attempt to close already closed stream %@", self);
      return;
    }
  [_tls bye];
#if	defined(__MINGW32__)
  if (_sibling && [_sibling streamStatus] != NSStreamStatusClosed)
    {
      /*
       * Windows only permits a single event to be associated with a socket
       * at any time, but the runloop system only allows an event handle to
       * be added to the loop once, and we have two streams for each socket.
       * So we use two events, one for each stream, and when one stream is
       * closed, we must call WSAEventSelect to ensure that the event handle
       * of the sibling is used to signal events from now on.
       */
      WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
      shutdown(_sock, SD_SEND);
      WSAEventSelect(_sock, [_sibling _loopID], FD_ALL_EVENTS);
    }
  else
    {
      closesocket(_sock);
    }
  WSACloseEvent(_loopID);
  [super close];
  _sock = INVALID_SOCKET;
  _loopID = WSA_INVALID_EVENT;
#else
  // read shutdown is ignored, because the other side may shutdown first.
  if (!_sibling || [_sibling streamStatus] == NSStreamStatusClosed)
    close((intptr_t)_loopID);
  else
    shutdown((intptr_t)_loopID, SHUT_WR);
  [super close];
  _loopID = (void*)(intptr_t)-1;
  _sock = -1;
#endif
}

- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len
{
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

  if (_tls == nil)
    return [self _write: buffer maxLength: len];
  else
    return [_tls write: buffer maxLength: len];
}

- (void) _dispatch
{
#if	defined(__MINGW32__)
  AUTORELEASE(RETAIN(self));
  /*
   * Windows only permits a single event to be associated with a socket
   * at any time, but the runloop system only allows an event handle to
   * be added to the loop once, and we have two streams for each socket.
   * So we use two events, one for each stream, and the _dispatch method
   * must handle things for both streams.
   */
  if ([self streamStatus] == NSStreamStatusClosed)
    {
      /*
       * It is possible the stream is closed yet recieving event because
       * of not closed sibling
       */
      NSAssert([_sibling streamStatus] != NSStreamStatusClosed, 
	@"Received event for closed stream");
      [_sibling _dispatch];
    }
  else
    {
      WSANETWORKEVENTS events;
      int error = 0;
      int getReturn = -1;

      if (WSAEnumNetworkEvents(_sock, _loopID, &events) == SOCKET_ERROR)
	{
	  error = WSAGetLastError();
	}
// else NSLog(@"EVENTS 0x%x on %p", events.lNetworkEvents, self);

      if ([self streamStatus] == NSStreamStatusOpening)
	{
	  [self _unschedule];
	  if (error == 0)
	    {
	      unsigned len = sizeof(error);

	      getReturn = getsockopt(_sock, SOL_SOCKET, SO_ERROR,
		(char*)&error, &len);
	    }

	  if (getReturn >= 0 && error == 0
	    && (events.lNetworkEvents & FD_CONNECT))
	    { // finish up the opening
	      events.lNetworkEvents ^= FD_CONNECT;
	      _passive = YES;
	      [self open];
	      // notify sibling
	      if (_sibling)
		{
		  [_sibling open];
		  [_sibling _sendEvent: NSStreamEventOpenCompleted];
		}
	      [self _sendEvent: NSStreamEventOpenCompleted];
	    }
	}

      if (error != 0)
	{
	  errno = error;
	  [self _recordError];
	  [_sibling _recordError];
	  [self _sendEvent: NSStreamEventErrorOccurred];
	  [_sibling _sendEvent: NSStreamEventErrorOccurred];
	}
      else
	{
	  if (events.lNetworkEvents & FD_WRITE)
	    {
	      /* Clear NSStreamStatusWriting if it was set */
	      [self _setStatus: NSStreamStatusOpen];
	    }

	  /* On winsock a socket is always writable unless it has had
	   * failure/closure or a write blocked and we have not been
	   * signalled again.
	   */
	  while ([self _unhandledData] == NO && [self hasSpaceAvailable])
	    {
	      [self _sendEvent: NSStreamEventHasSpaceAvailable];
	    }

	  if (events.lNetworkEvents & FD_READ)
	    {
	      [_sibling _setStatus: NSStreamStatusOpen];
	      while ([_sibling hasBytesAvailable]
		&& [_sibling _unhandledData] == NO)
		{
	          [_sibling _sendEvent: NSStreamEventHasBytesAvailable];
		}
	    }
	  if (events.lNetworkEvents & FD_CLOSE)
	    {
	      [self _setClosing: YES];
	      [_sibling _setClosing: YES];
	      while ([_sibling hasBytesAvailable]
		&& [_sibling _unhandledData] == NO)
		{
		  [_sibling _sendEvent: NSStreamEventHasBytesAvailable];
		}
	    }
	  if (events.lNetworkEvents == 0)
	    {
	      [self _sendEvent: NSStreamEventHasSpaceAvailable];
	    }
	}
    }
#else
  NSStreamEvent myEvent;

  if ([self streamStatus] == NSStreamStatusOpening)
    {
      int error;
      socklen_t len = sizeof(error);
      int result;

      AUTORELEASE(RETAIN(self));
      [self _schedule];
      result
	= getsockopt((intptr_t)_loopID, SOL_SOCKET, SO_ERROR, &error, &len);
      if (result >= 0 && !error)
        { // finish up the opening
          myEvent = NSStreamEventOpenCompleted;
          _passive = YES;
          [self open];
          // notify sibling
          [_sibling open];
          [_sibling _sendEvent: myEvent];
        }
      else // must be an error
        {
          if (error)
            errno = error;
          [self _recordError];
          myEvent = NSStreamEventErrorOccurred;
          [_sibling _recordError];
          [_sibling _sendEvent: myEvent];
        }
    }
  else if ([self streamStatus] == NSStreamStatusAtEnd)
    {
      myEvent = NSStreamEventEndEncountered;
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
      myEvent = NSStreamEventHasSpaceAvailable;
    }
  [self _sendEvent: myEvent];
#endif
}

#if	defined(__MINGW32__)
- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  *trigger = YES;
  if ([self _unhandledData] == YES && [self streamStatus] == NSStreamStatusOpen)
    {
      /* In winsock, a writable status is only signalled if an earlier
       * write failed (because it would block), so we must simulate the
       * writable event by having the run loop trigger without blocking.
       */
      return NO;
    }
  return YES;
}
#endif

@end

@implementation GSSocketServerStream

+ (void) initialize
{
  if (self == [GSSocketServerStream class])
    {
      GSObjCAddClassBehavior(self, [GSSocketStream class]);
    }
}

- (Class) _inputStreamClass
{
  [self subclassResponsibility: _cmd];
  return Nil;
}

- (Class) _outputStreamClass
{
  [self subclassResponsibility: _cmd];
  return Nil;
}

- (struct sockaddr*) _serverAddr
{
  [self subclassResponsibility: _cmd];
  return 0;
}

#define SOCKET_BACKLOG 256

- (void) open
{
  int bindReturn;
  int listenReturn;

#ifndef	BROKEN_SO_REUSEADDR
  /*
   * Under decent systems, SO_REUSEADDR means that the port can be reused
   * immediately that this process exits.  Under some it means
   * that multiple processes can serve the same port simultaneously.
   * We don't want that broken behavior!
   */
  int	status = 1;

  setsockopt([self _sock], SOL_SOCKET, SO_REUSEADDR,
    (char *)&status, sizeof(status));
#endif

  bindReturn = bind([self _sock], [self _serverAddr], [self _sockLen]);
  if (socketError(bindReturn))
    {
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
      return;
    }
  listenReturn = listen([self _sock], SOCKET_BACKLOG);
  if (socketError(listenReturn))
    {
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
      return;
    }
#if	defined(__MINGW32__)
  WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
#endif
  [super open];
}

- (void) close
{
#if	defined(__MINGW32__)
  if (_loopID != WSA_INVALID_EVENT)
    {
      WSACloseEvent(_loopID);
    }
  if (_sock != INVALID_SOCKET)
    {
      closesocket(_sock);
      _sock = INVALID_SOCKET;
      [super close];
      _loopID = WSA_INVALID_EVENT;
    }
#else
  if (_loopID != (void*)(intptr_t)-1)
    {
      close((intptr_t)_loopID);
      [super close];
      _loopID = (void*)(intptr_t)-1;
    }
#endif
}

- (void) acceptWithInputStream: (NSInputStream **)inputStream 
                  outputStream: (NSOutputStream **)outputStream
{
  GSSocketStream *ins = AUTORELEASE([[self _inputStreamClass] new]);
  GSSocketStream *outs = AUTORELEASE([[self _outputStreamClass] new]);
  socklen_t len = [ins _sockLen];
  int acceptReturn = accept([self _sock], [ins _peerAddr], &len);

  _events &= ~NSStreamEventHasBytesAvailable;
  if (socketError(acceptReturn))
    { // test for real error
      if (!socketWouldBlock())
	{
          [self _recordError];
	}
      ins = nil;
      outs = nil;
    }
  else
    {
      // no need to connect again
      [ins _setPassive: YES];
      [outs _setPassive: YES];
      // copy the addr to outs
      memcpy([outs _peerAddr], [ins _peerAddr], len);
      [ins _setSock: acceptReturn];
      [outs _setSock: acceptReturn];
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

- (void) _dispatch
{
#if	defined(__MINGW32__)
  WSANETWORKEVENTS events;
  
  if (WSAEnumNetworkEvents(_sock, _loopID, &events) == SOCKET_ERROR)
    {
      errno = WSAGetLastError();
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
    }
  else if (events.lNetworkEvents & FD_ACCEPT)
    {
      events.lNetworkEvents ^= FD_ACCEPT;
      [self _setStatus: NSStreamStatusReading];
      [self _sendEvent: NSStreamEventHasBytesAvailable];
    }
#else
  NSStreamEvent myEvent;

  [self _setStatus: NSStreamStatusOpen];
  myEvent = NSStreamEventHasBytesAvailable;
  [self _sendEvent: myEvent];
#endif
}

@end






static id propertyForInet4Stream(int descriptor, NSString *key)
{
  struct sockaddr_in sin;
  unsigned	size = sizeof(sin);
  id		result = nil;

  if ([key isEqualToString: GSStreamLocalAddressKey])
    {
      if (getsockname(descriptor, (struct sockaddr*)&sin, &size) != -1)
        {
	  result = [NSString stringWithUTF8String:
	    (char*)inet_ntoa(sin.sin_addr)];
	}
    }
  else if ([key isEqualToString: GSStreamLocalPortKey])
    {
      if (getsockname(descriptor, (struct sockaddr*)&sin, &size) != -1)
        {
	  result = [NSString stringWithFormat: @"%d",
	    (int)GSSwapBigI16ToHost(sin.sin_port)];
	}
    }
  else if ([key isEqualToString: GSStreamRemoteAddressKey])
    {
      if (getpeername(descriptor, (struct sockaddr*)&sin, &size) != -1)
        {
	  result = [NSString stringWithUTF8String:
	    (char*)inet_ntoa(sin.sin_addr)];
	}
    }
  else if ([key isEqualToString: GSStreamRemotePortKey])
    {
      if (getpeername(descriptor, (struct sockaddr*)&sin, &size) != -1)
        {
	  result = [NSString stringWithFormat: @"%d",
	    (int)GSSwapBigI16ToHost(sin.sin_port)];
	}
    }
  return result;
}
#if	defined(AF_INET6)
static id propertyForInet6Stream(int descriptor, NSString *key)
{
  struct sockaddr_in6 sin;
  unsigned	size = sizeof(sin);
  id		result = nil;

  if ([key isEqualToString: GSStreamLocalAddressKey])
    {
      if (getsockname(descriptor, (struct sockaddr*)&sin, &size) != -1)
        {
	  char	buf[INET6_ADDRSTRLEN+1];

	  if (inet_ntop(AF_INET6, &(sin.sin6_addr), buf, INET6_ADDRSTRLEN) == 0)
	    {
	      buf[INET6_ADDRSTRLEN] = '\0';
	      result = [NSString stringWithUTF8String: buf];
	    }
	}
    }
  else if ([key isEqualToString: GSStreamLocalPortKey])
    {
      if (getsockname(descriptor, (struct sockaddr*)&sin, &size) != -1)
        {
	  result = [NSString stringWithFormat: @"%d",
	    (int)GSSwapBigI16ToHost(sin.sin6_port)];
	}
    }
  else if ([key isEqualToString: GSStreamRemoteAddressKey])
    {
      if (getpeername(descriptor, (struct sockaddr*)&sin, &size) != -1)
        {
	  char	buf[INET6_ADDRSTRLEN+1];

	  if (inet_ntop(AF_INET6, &(sin.sin6_addr), buf, INET6_ADDRSTRLEN) == 0)
	    {
	      buf[INET6_ADDRSTRLEN] = '\0';
	      result = [NSString stringWithUTF8String: buf];
	    }
	}
    }
  else if ([key isEqualToString: GSStreamRemotePortKey])
    {
      if (getpeername(descriptor, (struct sockaddr*)&sin, &size) != -1)
        {
	  result = [NSString stringWithFormat: @"%d",
	    (int)GSSwapBigI16ToHost(sin.sin6_port)];
	}
    }
  return result;
}
#endif

@implementation GSInetInputStream

- (socklen_t) _sockLen
{
  return sizeof(struct sockaddr_in);
}

- (struct sockaddr*) _peerAddr
{
  return (struct sockaddr*)&_peerAddr;
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  int           ptonReturn;
  const char    *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sin_family = AF_INET;
      _peerAddr.sin_port = GSSwapHostI16ToBig(port);
      ptonReturn = inet_pton(AF_INET, addr_c, &(_peerAddr.sin_addr));
      if (ptonReturn == 0)   // error
	{
	  DESTROY(self);
	}
    }
  return self;
}

- (id) propertyForKey: (NSString *)key
{
  id result = propertyForInet4Stream((intptr_t)_loopID, key);

  if (result == nil)
    {
      result = [super propertyForKey: key];
    }
  return result;
}

@end

@implementation GSInet6InputStream
#if	defined(AF_INET6)
- (socklen_t) _sockLen
{
  return sizeof(struct sockaddr_in6);
}

- (struct sockaddr*) _peerAddr
{
  return (struct sockaddr*)&_peerAddr;
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  int ptonReturn;
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sin6_family = AF_INET6;
      _peerAddr.sin6_port = GSSwapHostI16ToBig(port);
      ptonReturn = inet_pton(AF_INET6, addr_c, &(_peerAddr.sin6_addr));
      if (ptonReturn == 0)   // error
	{
	  DESTROY(self);
	}
    }
  return self;
}

- (id) propertyForKey: (NSString *)key
{
  id result = propertyForInet6Stream((intptr_t)_loopID, key);

  if (result == nil)
    {
      result = [super propertyForKey: key];
    }
  return result;
}

#else
- (id) initToAddr: (NSString*)addr port: (int)port
{
  RELEASE(self);
  return nil;
}
#endif
@end

@implementation GSInetOutputStream

- (socklen_t) _sockLen
{
  return sizeof(struct sockaddr_in);
}

- (struct sockaddr*) _peerAddr
{
  return (struct sockaddr*)&_peerAddr;
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  int ptonReturn;
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sin_family = AF_INET;
      _peerAddr.sin_port = GSSwapHostI16ToBig(port);
      ptonReturn = inet_pton(AF_INET, addr_c, &(_peerAddr.sin_addr));
      if (ptonReturn == 0)   // error
	{
	  DESTROY(self);
	}
    }
  return self;
}

- (id) propertyForKey: (NSString *)key
{
  id result = propertyForInet4Stream((intptr_t)_loopID, key);

  if (result == nil)
    {
      result = [super propertyForKey: key];
    }
  return result;
}

@end

@implementation GSInet6OutputStream
#if	defined(AF_INET6)
- (socklen_t) _sockLen
{
  return sizeof(struct sockaddr_in6);
}

- (struct sockaddr*) _peerAddr
{
  return (struct sockaddr*)&_peerAddr;
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  int ptonReturn;
  const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

  if ((self = [super init]) != nil)
    {
      _peerAddr.sin6_family = AF_INET6;
      _peerAddr.sin6_port = GSSwapHostI16ToBig(port);
      ptonReturn = inet_pton(AF_INET6, addr_c, &(_peerAddr.sin6_addr));
      if (ptonReturn == 0)   // error
	{
	  DESTROY(self);
	}
    }
  return self;
}

- (id) propertyForKey: (NSString *)key
{
  id result = propertyForInet6Stream((intptr_t)_loopID, key);

  if (result == nil)
    {
      result = [super propertyForKey: key];
    }
  return result;
}

#else
- (id) initToAddr: (NSString*)addr port: (int)port
{
  RELEASE(self);
  return nil;
}
#endif
@end

@implementation GSInetServerStream

- (Class) _inputStreamClass
{
  return [GSInetInputStream class];
}

- (Class) _outputStreamClass
{
  return [GSInetOutputStream class];
}

- (socklen_t) _sockLen
{
  return sizeof(struct sockaddr_in);
}

- (struct sockaddr*) _serverAddr
{
  return (struct sockaddr*)&_serverAddr;
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  if ((self = [super init]) != nil)
    {
      int ptonReturn;
      const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

      _serverAddr.sin_family = AF_INET;
      _serverAddr.sin_port = GSSwapHostI16ToBig(port);
      if (addr_c == 0)
        {
          addr_c = "0.0.0.0";   /* Bind on all addresses */
        }
      ptonReturn = inet_pton(AF_INET, addr_c, &(_serverAddr.sin_addr));
      if (ptonReturn == 0)   // error
        {
          DESTROY(self);
        }
      else
        {
          SOCKET        s;

          s = socket(AF_INET, SOCK_STREAM, 0);
          if (BADSOCKET(s))
            {
              DESTROY(self);
            }
          else
            {
              [self _setSock: s];
            }
        }
    }
  return self;
}

@end

@implementation GSInet6ServerStream
#if	defined(AF_INET6)
- (Class) _inputStreamClass
{
  return [GSInet6InputStream class];
}

- (Class) _outputStreamClass
{
  return [GSInet6OutputStream class];
}

- (socklen_t) _sockLen
{
  return sizeof(struct sockaddr_in6);
}

- (struct sockaddr*) _serverAddr
{
  return (struct sockaddr*)&_serverAddr;
}

- (id) initToAddr: (NSString*)addr port: (int)port
{
  if ([super init] != nil)
    {
      int ptonReturn;
      const char *addr_c = [addr cStringUsingEncoding: NSUTF8StringEncoding];

      _serverAddr.sin6_family = AF_INET6;
      _serverAddr.sin6_port = GSSwapHostI16ToBig(port);
      if (addr_c == 0)
        {
          addr_c = "0:0:0:0:0:0:0:0";   /* Bind on all addresses */
        }
      ptonReturn = inet_pton(AF_INET6, addr_c, &(_serverAddr.sin6_addr));
      if (ptonReturn == 0)   // error
        {
          DESTROY(self);
        }
      else
        {
          SOCKET        s;

          s = socket(AF_INET6, SOCK_STREAM, 0);
          if (BADSOCKET(s))
            {
              DESTROY(self);
            }
          else
            {
              [self _setSock: s];
            }
        }
    }
  return self;
}
#else
- (id) initToAddr: (NSString*)addr port: (int)port
{
  RELEASE(self);
  return nil;
}
#endif
@end


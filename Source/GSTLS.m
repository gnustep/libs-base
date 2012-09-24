/** Implementation for GSTLS classes for GNUStep
   Copyright (C) 2012 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2101

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

#import "common.h"

#import "Foundation/NSArray.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSHost.h"
#import "Foundation/NSException.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSUserDefaults.h"

#import "GSTLS.h"

#import "GSPrivate.h"

NSString * const GSTLSCertificateFile = @"GSTLSCertificateFile";
NSString * const GSTLSPrivateKeyFile = @"GSTLSPrivateKeyFile";
NSString * const GSTLSPrivateKeyPassword = @"GSTLSPrivateKeyPassword";

#if     defined(HAVE_GNUTLS)

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

static void
GSTLSLog(int level, const char *msg)
{
  NSLog(@"%s", msg);
}

static NSString *cipherList = nil;

static gnutls_anon_client_credentials_t anoncred;

/* This class is used to ensure that the GNUTLS system is initialised
 * and thread-safe.
 */
@implementation GSTLSObject

+ (void) _defaultsChanged: (NSNotification*)n
{
  cipherList
    = [[NSUserDefaults standardUserDefaults] stringForKey: @"GSCipherList"];
}

+ (void) initialize
{
  if ([GSTLSObject class] == self)
    {
      static BOOL   beenHere = NO;

      if (beenHere == NO)
        {
          NSUserDefaults	*defs;

          beenHere = YES;

          defs = [NSUserDefaults standardUserDefaults];
          cipherList = [defs stringForKey: @"GSCipherList"];
          [[NSNotificationCenter defaultCenter]
            addObserver: self
               selector: @selector(_defaultsChanged:)
                   name: NSUserDefaultsDidChangeNotification
                 object: nil];

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
        }
    }
}

+ (int) verify: (gnutls_session_t)session
{
  unsigned int          status;
  const gnutls_datum_t  *cert_list;
  unsigned int          cert_list_size;
  int                   ret;
  gnutls_x509_crt_t     cert;
  id <GSTLSOwner>       owner;
  NSHost                *host;
  NSDictionary          *options;

  /* read hostname */
  owner = (id<GSTLSOwner>)gnutls_session_get_ptr(session);
  host = [owner remoteHost];
  options = [owner options];

  /* This verification function uses the trusted CAs in the credentials
   * structure. So you must have installed one or more CA certificates.
   */
  ret = gnutls_certificate_verify_peers2 (session, &status);
  if (ret < 0)
    {
      NSLog(@"Error");
      return GNUTLS_E_CERTIFICATE_ERROR;
    }

  if (status & GNUTLS_CERT_SIGNER_NOT_FOUND)
    NSLog(@"The certificate hasn't got a known issuer.");

  if (status & GNUTLS_CERT_REVOKED)
    NSLog(@"The certificate has been revoked.");

/*
  if (status & GNUTLS_CERT_EXPIRED)
    NSLog(@"The certificate has expired");

  if (status & GNUTLS_CERT_NOT_ACTIVATED)
    NSLog(@"The certificate is not yet activated");
*/

  if (status & GNUTLS_CERT_INVALID)
    {
      NSLog(@"The certificate is not trusted.");
      return GNUTLS_E_CERTIFICATE_ERROR;
    }

  /* Up to here the process is the same for X.509 certificates and
   * OpenPGP keys. From now on X.509 certificates are assumed. This can
   * be easily extended to work with openpgp keys as well.
   */
  if (gnutls_certificate_type_get (session) != GNUTLS_CRT_X509)
    return GNUTLS_E_CERTIFICATE_ERROR;

  if (gnutls_x509_crt_init (&cert) < 0)
    {
      NSLog(@"error in initialization");
      return GNUTLS_E_CERTIFICATE_ERROR;
    }

  cert_list = gnutls_certificate_get_peers (session, &cert_list_size);
  if (cert_list == NULL)
    {
      NSLog(@"No certificate was found!");
      return GNUTLS_E_CERTIFICATE_ERROR;
    }

  if (gnutls_x509_crt_import (cert, &cert_list[0], GNUTLS_X509_FMT_DER) < 0)
    {
      NSLog(@"error parsing certificate");
      return GNUTLS_E_CERTIFICATE_ERROR;
    }

  if (nil != host)
    {
      NSEnumerator      *enumerator = [[host names] objectEnumerator];
      BOOL              found = NO;
      NSString          *name;

      while (nil != (name = [enumerator nextObject]))
        {
          if (0 == gnutls_x509_crt_check_hostname(cert, [name UTF8String]))
            {
              found = YES;
              break;
            }
        }
      if (NO == found)
        {
          NSLog(@"The certificate's owner does not match host '%@'", host);
          gnutls_x509_crt_deinit (cert);
          return GNUTLS_E_CERTIFICATE_ERROR;
        }
    }

  gnutls_x509_crt_deinit (cert);

  return 0;     // Verified
}

@end

@implementation GSTLSDHParams
static NSLock                   *paramsLock = nil;
static NSMutableDictionary      *paramsCache = nil;
static NSDate                   *paramsWhen = nil;
static BOOL                     paramsGenerating = NO;
static GSTLSDHParams            *paramsCurrent = nil;

+ (GSTLSDHParams*) current
{
  GSTLSDHParams *p;

  [paramsLock lock];
  if (nil == paramsCurrent)
    {
      if (NO == paramsGenerating)
        {
          [paramsLock unlock];
          [self generate];
          [paramsLock lock];
        }
      while (nil == paramsCurrent)
        {
          [paramsLock unlock];
          [NSThread sleepForTimeInterval: 0.2];
          [paramsLock lock];
        }
    }
  p = [paramsCurrent retain];
  [paramsLock unlock];
  return [paramsCurrent autorelease];
}

+ (void) generate
{
  GSTLSDHParams         *p;

  [paramsLock lock];
  if (YES == paramsGenerating)
    {
      [paramsLock unlock];
      return;
    }
  paramsGenerating = YES;
  [paramsLock unlock];

  p = [GSTLSDHParams new];
  /* Generate Diffie-Hellman parameters - for use with DHE
   * kx algorithms. When short bit length is used, it might
   * be wise to regenerate parameters often.
   */
  gnutls_dh_params_init (&p->params);
  gnutls_dh_params_generate2 (p->params, 2048);
  [paramsLock lock];
  [paramsCurrent release];
  paramsCurrent = p;
  ASSIGN(paramsWhen, [NSDate date]);
  paramsGenerating = NO;
  [paramsLock unlock];
}

+ (void) housekeeping: (NSNotification*)n
{
  NSEnumerator  *enumerator;
  NSString      *key;
  NSDate        *now;

  now = [NSDate date];
  [paramsLock lock];

  enumerator = [[paramsCache allKeys] objectEnumerator];
  while (nil != (key = [enumerator nextObject]))
    {
      GSTLSDHParams     *p;

      p = [paramsCache objectForKey: key];

      if ([now timeIntervalSinceDate: p->when] > 300.0)
        {
          [paramsCache removeObjectForKey: key];
        }
    }

  /* Regenerate DH params once per day, perfoming generation in another
   * thread since it's likely to be rather slow.
   */
  if (nil != paramsCurrent && NO == paramsGenerating
    && [now timeIntervalSinceDate: paramsWhen] > 24 * 60 * 60)
    {
      [NSThread detachNewThreadSelector: @selector(generate)
                               toTarget: self
                             withObject: nil];
    }
  [paramsLock unlock];
}

+ (void) initialize
{
  if (nil == paramsLock)
    {
      paramsLock = [NSLock new];
      paramsWhen = [NSDate new];
      paramsCache = [NSMutableDictionary new];
      [[NSNotificationCenter defaultCenter] addObserver: self
	selector: @selector(housekeeping:)
	name: @"GSHousekeeping" object: nil];
    }
}

+ (GSTLSDHParams*) paramsFromFile: (NSString*)f
{
  GSTLSDHParams *p;

  if (nil == f)
    {
      return nil;
    }
  [paramsLock lock];
  p = [[paramsCache objectForKey: f] retain];
  [paramsLock unlock];

  if (nil == p)
    {
      NSData                    *data;
      int                       ret;
      gnutls_datum_t            datum;

      data = [NSData dataWithContentsOfFile: f];
      if (nil == data)
        {
          NSLog(@"Unable to read DF params file '%@'", f);
          return nil;
        }
      datum.data = (unsigned char*)[data bytes];
      datum.size = (unsigned int)[data length];

      p = [self alloc];
      p->when = [NSDate new];
      p->path = [f copy];
      gnutls_dh_params_init(&p->params);
      ret = gnutls_dh_params_import_pkcs3(p->params, &datum,
        GNUTLS_X509_FMT_PEM);
      if (ret < 0)
        {
          NSLog(@"Unable to parse DH params file '%@': %s",
            p->path, gnutls_strerror(ret));
          [p release];
          return nil;
        }
      [paramsLock lock];
      [paramsCache setObject: p forKey: p->path];
      [paramsLock unlock];
    }

  return [p autorelease];
}

- (void) dealloc
{
  gnutls_dh_params_deinit (params);
  [super dealloc];
}

- (gnutls_dh_params_t) params
{
  return params;
}

@end

@implementation GSTLSCertificateList

static NSLock                   *certificateListLock = nil;
static NSMutableDictionary      *certificateListCache = nil;

/* Method to purge older lists from cache.
 */
+ (void) housekeeping: (NSNotification*)n
{
  NSEnumerator  *enumerator;
  NSString      *key;
  NSDate        *now;

  now = [NSDate date];
  [certificateListLock lock];
  enumerator = [[certificateListCache allKeys] objectEnumerator];
  while (nil != (key = [enumerator nextObject]))
    {
      GSTLSCertificateList      *list;

      list = [certificateListCache objectForKey: key];

      if ([now timeIntervalSinceDate: list->when] > 300.0)
        {
          [certificateListCache removeObjectForKey: key];
        }
    }
  [certificateListLock unlock];
}

+ (void) initialize
{
  if (nil == certificateListLock)
    {
      certificateListLock = [NSLock new];
      certificateListCache = [NSMutableDictionary new];
      [[NSNotificationCenter defaultCenter] addObserver: self
	selector: @selector(housekeeping:)
	name: @"GSHousekeeping" object: nil];
    }
}

+ (GSTLSCertificateList*) listFromFile: (NSString*)f
{
  GSTLSCertificateList  *l;

  if (nil == f)
    {
      return nil;
    }
  [certificateListLock lock];
  l = [[certificateListCache objectForKey: f] retain];
  [certificateListLock unlock];

  if (nil == l)
    {
      NSData                    *data;
      int                       ret;
      gnutls_datum_t            datum;
      unsigned int              count = 100;
      gnutls_x509_crt_t         crts[count];

      data = [NSData dataWithContentsOfFile: f];
      if (nil == data)
        {
          NSLog(@"Unable to read certificate file '%@'", f);
          return nil;
        }
      datum.data = (unsigned char*)[data bytes];
      datum.size = (unsigned int)[data length];

      l = [self alloc];
      l->when = [NSDate new];
      l->path = [f copy];
      ret = gnutls_x509_crt_list_import(crts, &count, &datum,
        GNUTLS_X509_FMT_PEM,
//            GNUTLS_X509_CRT_LIST_FAIL_IF_UNSORTED |
        GNUTLS_X509_CRT_LIST_IMPORT_FAIL_IF_EXCEED);
      if (ret < 0)
        {
          NSLog(@"Unable to parse certificate file '%@': %s",
            l->path, gnutls_strerror(ret));
          [l release];
          return nil;
        }
      l->crts = malloc(sizeof(gnutls_x509_crt_t) * count);
      memcpy(l->crts, crts, sizeof(gnutls_x509_crt_t) * count);
      l->count = count;

      [certificateListLock lock];
      [certificateListCache setObject: l forKey: l->path];
      [certificateListLock unlock];
    }

  return [l autorelease];
}

- (gnutls_x509_crt_t*) certificateList
{
  return crts;
}

- (unsigned int) count
{
  return count;
}

- (void) dealloc
{
  if (nil != path)
    {
      DESTROY(when);
      DESTROY(path);
      if (count > 0)
        {
          while (count-- > 0)
            {
              gnutls_x509_crt_deinit(crts[count]);
            }
          free(crts);
        }
    }
  [super dealloc];
}

@end


@implementation GSTLSPrivateKey

static NSLock                   *privateKeyLock = nil;
static NSMutableDictionary      *privateKeyCache0 = nil;
static NSMutableDictionary      *privateKeyCache1 = nil;

/* Method to purge older keys from cache.
 */
+ (void) housekeeping: (NSNotification*)n
{
  NSEnumerator  *outer;
  NSString      *oKey;
  NSDate        *now;

  now = [NSDate date];
  [privateKeyLock lock];
  outer = [[privateKeyCache0 allKeys] objectEnumerator];
  while (nil != (oKey = [outer nextObject]))
    {
      GSTLSPrivateKey   *key;

      key = [privateKeyCache0 objectForKey: oKey];
      if ([now timeIntervalSinceDate: key->when] > 300.0)
        {
          [privateKeyCache0 removeObjectForKey: oKey];
        }
    }
  outer = [[privateKeyCache1 allKeys] objectEnumerator];
  while (nil != (oKey = [outer nextObject]))
    {
      NSMutableDictionary       *m;
      NSEnumerator              *inner;
      NSString                  *iKey;

      m = [privateKeyCache1 objectForKey: oKey];
      inner = [[m allKeys] objectEnumerator];
      while (nil != (iKey = [inner nextObject]))
        {
          GSTLSPrivateKey       *key = [m objectForKey: iKey];

          if ([now timeIntervalSinceDate: key->when] > 300.0)
            {
              [m removeObjectForKey: iKey];
              if (0 == [m count])
                {
                  [privateKeyCache1 removeObjectForKey: oKey];
                }
            }
        }
    }
  [privateKeyLock unlock];
}

+ (void) initialize
{
  if (nil == privateKeyLock)
    {
      privateKeyLock = [NSLock new];
      privateKeyCache0 = [NSMutableDictionary new];
      privateKeyCache1 = [NSMutableDictionary new];

      [[NSNotificationCenter defaultCenter] addObserver: self
	selector: @selector(housekeeping:)
	name: @"GSHousekeeping" object: nil];
    }
}

+ (GSTLSPrivateKey*) keyFromFile: (NSString*)f withPassword: (NSString*)p
{
  GSTLSPrivateKey       *k;

  if (nil == f)
    {
      return nil;
    }
  [privateKeyLock lock];
  if (nil == p)
    {
      k = [privateKeyCache0 objectForKey: f];
    }
  else
    {
      NSMutableDictionary       *m;

      m = [privateKeyCache1 objectForKey: f];
      if (nil == m)
        {
          k = nil;
        }
      else
        {
          k = [m objectForKey: p];
        }
    }
  [k retain];
  [privateKeyLock unlock];

  if (nil == k)
    {
      NSData                    *data;
      int                       ret;
      gnutls_datum_t            datum;

      data = [NSData dataWithContentsOfFile: f];
      if (nil == data)
        {
          NSLog(@"Unable to read private key file '%@'", f);
          return nil;
        }
      datum.data = (unsigned char*)[data bytes];
      datum.size = (unsigned int)[data length];

      k = [self alloc];
      k->when = [NSDate new];
      k->path = [f copy];
      k->password = [p copy];
      gnutls_x509_privkey_init(&k->key);

      if (nil == k->password)
        {
          ret = gnutls_x509_privkey_import(k->key, &datum,
            GNUTLS_X509_FMT_PEM);
        }
      else
        {
          ret = gnutls_x509_privkey_import_pkcs8(k->key, &datum,
            GNUTLS_X509_FMT_PEM, [k->password UTF8String], 0);
        }
      if (ret < 0)
        {
          NSLog(@"Unable to parse private key file '%@': %s",
            k->path, gnutls_strerror(ret));
          [k release];
          return nil;
        }
      [privateKeyLock lock];
      if (nil == k->password)
        {
          [privateKeyCache0 setObject: k forKey: k->path];
        }
      else
        {
          NSMutableDictionary   *m;

          m = [privateKeyCache1 objectForKey: f];
          if (nil == m)
            {
              m = [NSMutableDictionary new];
              [privateKeyCache1 setObject: m forKey: f];
              [m release];
            }
          [m setObject: k forKey: p];
        }
      [privateKeyLock unlock];
    }

  return [k autorelease];
}

- (void) dealloc
{
  if (nil != path)
    {
      DESTROY(when);
      DESTROY(path);
      DESTROY(password);
      gnutls_x509_privkey_deinit(key);
    }
  [super dealloc];
}

- (gnutls_x509_privkey_t) key
{
  return key;
}
@end

#endif


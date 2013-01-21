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
#import "Foundation/NSBundle.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSHost.h"
#import "Foundation/NSException.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSProcessInfo.h"
#import "Foundation/NSStream.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSUserDefaults.h"

#import "GSTLS.h"

#import "GSPrivate.h"

/* Constants to control TLS/SSL (options).
 */
NSString * const GSTLSCAFile = @"GSTLSCAFile";
NSString * const GSTLSCertificateFile = @"GSTLSCertificateFile";
NSString * const GSTLSCertificateKeyFile = @"GSTLSCertificateKeyFile";
NSString * const GSTLSCertificateKeyPassword = @"GSTLSCertificateKeyPassword";
NSString * const GSTLSDebug = @"GSTLSDebug";
NSString * const GSTLSPriority = @"GSTLSPriority";
NSString * const GSTLSRemoteHosts = @"GSTLSRemoteHosts";
NSString * const GSTLSRevokeFile = @"GSTLSRevokeFile";
NSString * const GSTLSVerify = @"GSTLSVerify";


#if     defined(HAVE_GNUTLS)

/* Set up locking callbacks for gcrypt so that it will be thread-safe.
 */
static int gcry_mutex_init(void **priv)
{
  NSLock        *lock = [NSLock new];
  *priv = (void*)lock;
  return 0;
}
static int gcry_mutex_destroy(void **lock)
{
  [((NSLock*)*lock) release];
  return 0;
}
static int gcry_mutex_lock(void **lock)
{
  [((NSLock*)*lock) lock];
  return 0;
}
static int gcry_mutex_unlock(void **lock)
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

/* The caFile variable holds the location of the file containing the default
 * certificate authorities to be used by our system.
 * The hard-coded value is a file in the GSTLS folder of the base library
 * resource bundle, but this can be overridden by the GS_TLS_CA_FILE
 * environment variable, which in turn will be overridden by the GSTLSCAFile
 * user default string.
 */
static NSString *caFile = nil;          // GSTLS/ca-certificates.crt

/* The caRevoke variable holds the location of the file containing the default
 * certificate revocation list to be used by our system.
 * The hard-coded value is a file in the GSTLS folder of the base library
 * resource bundle, but this can be overridden by the GS_TLS_REVOKE
 * environment variable, which in turn will be overridden by the GSTLSRevokeFile
 * user default string.
 */
static NSString *revokeFile = nil;      // GSTLS/revoke.crl

/* The verifyClient variable tells us if connections from a remote server
 * should (by default) require and verify a client certificate against
 * trusted authorities.
 * The hard-coded value can be overridden by the GS_TLS_VERIFY_C environment
 * variable, which in turn will be overridden by the GSTLSVerifyClient user
 * default string.
 * A GSTLSVerify option set for a specific session overrides this default
 */
static BOOL     verifyClient = NO;

/* The verifyServer variable tells us if connections to a remote server should
 * (by default) verify its certificate against trusted authorities.
 * The hard-coded value can be overridden by the GS_TLS_VERIFY_S environment
 * variable, which in turn will be overridden by the GSTLSVerifyServer user
 * default string.
 * A GSTLSVerify option set for a specific session overrides this default
 */
static BOOL     verifyServer = NO;

/* The globalDebug variable turns on gnutls debug.  The hard-code value is
 * overridden by GS_TLS_DEBUG, which in turn can be overridden by the
 * GSTLSDebug user default. This is an integer debug level with higher
 * values producing more debug output.  Usually levels above 1 are too
 * verbose and not useful unless you have the gnutls source code to hand.
 * NB. The GSTLSDebug session option is a boolean to turn on extra debug for
 * a particular session to be produced on verification failure.
 */
static int      globalDebug = 0;

/* Defines the default priority list.
 */
static NSString *priority = nil;

static gnutls_anon_client_credentials_t anoncred;

/* This class is used to ensure that the GNUTLS system is initialised
 * and thread-safe.
 */
@implementation GSTLSObject

+ (void) _defaultsChanged: (NSNotification*)n
{
  NSString      *str;

  str = [[NSUserDefaults standardUserDefaults] stringForKey: @"GSCipherList"];
  if (nil != str)
    {
      GSOnceMLog(@"GSCipherList is no longer used, please try GSTLSPriority");
    }

  str = [[NSUserDefaults standardUserDefaults] stringForKey: GSTLSPriority];
  if (nil != str)
    {
      ASSIGN(priority, str);
    }

  /* The GSTLSCAFile user default overrides the builtin value or the
   * GS_TLS_CA_FILE environment variable.
   */
  str = [[NSUserDefaults standardUserDefaults] stringForKey: GSTLSCAFile];
  if (nil != str)
    {
      str = [str stringByStandardizingPath];
      ASSIGN(caFile, str);
    }

  /* The GSTLSRevokeFile user default overrides the builtin value or the
   * GS_TLS_REVOKE environment variable.
   */
  str = [[NSUserDefaults standardUserDefaults] stringForKey: GSTLSRevokeFile];
  if (nil != str)
    {
      str = [str stringByStandardizingPath];
      ASSIGN(revokeFile, str);
    }

  str = [[NSUserDefaults standardUserDefaults]
    stringForKey: @"GSTLSVerifyClient"];
  if (nil != str)
    {
      verifyClient = [str boolValue];
    }

  str = [[NSUserDefaults standardUserDefaults]
    stringForKey: @"GSTLSVerifyServer"];
  if (nil != str)
    {
      verifyServer = [str boolValue];
    }

  str = [[NSUserDefaults standardUserDefaults] stringForKey: GSTLSDebug];
  if (nil != str)
    {
      globalDebug = [str intValue];
    }
  if (globalDebug < 0)
    {
      globalDebug = 0;
    }
  gnutls_global_set_log_level(globalDebug);
}

+ (void) initialize
{
  if ([GSTLSObject class] == self)
    {
      static BOOL   beenHere = NO;

      if (beenHere == NO)
        {
          NSProcessInfo         *pi;
          NSBundle              *bundle;
          NSString              *str;

          beenHere = YES;

          bundle = [NSBundle bundleForClass: [NSObject class]];

          /* Let the GS_TLS_CA_FILE environment variable override the
           * default certificate authority location.
           */
          pi = [NSProcessInfo processInfo];
          str = [[pi environment] objectForKey: @"GS_TLS_CA_FILE"];
          if (nil == str)
            {
              str = [bundle pathForResource: @"ca-certificates"
                                     ofType: @"crt"
                                inDirectory: @"GSTLS"];
            }
          else
            {
              str = [str stringByStandardizingPath];
            }
          ASSIGN(caFile, str);

          /* Let the GS_TLS_REVOKE environment variable override the
           * default revocation list location.
           */
          pi = [NSProcessInfo processInfo];
          str = [[pi environment] objectForKey: @"GS_TLS_REVOKE"];
          if (nil == str)
            {
              str = [bundle pathForResource: @"revoke"
                                     ofType: @"crl"
                                inDirectory: @"GSTLS"];
            }
          else
            {
              str = [str stringByStandardizingPath];
            }
          ASSIGN(revokeFile, str);

          str = [[pi environment] objectForKey: @"GS_TLS_VERIFY_C"];
          if (nil != str)
            {
              verifyClient = [str boolValue];
            }

          str = [[pi environment] objectForKey: @"GS_TLS_VERIFY_S"];
          if (nil != str)
            {
              verifyServer = [str boolValue];
            }

          str = [[pi environment] objectForKey: @"GS_TLS_DEBUG"];
          if (nil != str)
            {
              globalDebug = [str intValue];
            }

          [[NSNotificationCenter defaultCenter]
            addObserver: self
               selector: @selector(_defaultsChanged:)
                   name: NSUserDefaultsDidChangeNotification
                 object: nil];

          /* Make gcrypt thread-safe
           */
          gcry_control(GCRYCTL_SET_THREAD_CBS, &gcry_threads_other);

          /* Initialise gnutls
           */
          gnutls_global_init();

          /* Allocate global credential information for anonymous tls
           */
          gnutls_anon_allocate_client_credentials(&anoncred);

          /* Enable gnutls logging via NSLog
           */
          gnutls_global_set_log_function(GSTLSLog);

          [self _defaultsChanged: nil];
        }
    }
}

@end

@implementation GSTLSDHParams
static NSLock                   *paramsLock = nil;
static NSMutableDictionary      *paramsCache = nil;
static NSTimeInterval           paramsWhen = 0.0;
static BOOL                     paramsGenerating = NO;
static GSTLSDHParams            *paramsCurrent = nil;

+ (GSTLSDHParams*) current
{
  GSTLSDHParams	*p; 
  
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
  return [p autorelease];
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
  gnutls_dh_params_init(&p->params);
  gnutls_dh_params_generate2 (p->params, 2048);
  [paramsLock lock];
  [paramsCurrent release];
  paramsCurrent = p;
  paramsWhen = [NSDate timeIntervalSinceReferenceDate];
  paramsGenerating = NO;
  [paramsLock unlock];
}

+ (void) housekeeping: (NSNotification*)n
{
  NSEnumerator          *enumerator;
  NSString              *key;
  NSTimeInterval        now;

  now = [NSDate timeIntervalSinceReferenceDate];
  [paramsLock lock];

  enumerator = [[paramsCache allKeys] objectEnumerator];
  while (nil != (key = [enumerator nextObject]))
    {
      GSTLSDHParams     *p;

      p = [paramsCache objectForKey: key];

      if (now - p->when > 300.0)
        {
          [paramsCache removeObjectForKey: key];
        }
    }

  /* Regenerate DH params once per day, perfoming generation in another
   * thread since it's likely to be rather slow.
   */
  if (nil != paramsCurrent && NO == paramsGenerating
    && (now = paramsWhen) > 24.0 * 60.0 * 60.0)
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
      paramsWhen = [NSDate timeIntervalSinceReferenceDate];
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
  f = [f stringByStandardizingPath];
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
      p->when = [NSDate timeIntervalSinceReferenceDate];
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
  gnutls_dh_params_deinit(params);
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

+ (void) certInfo: (gnutls_x509_crt_t)cert to: (NSMutableString*)str
{
  char            dn[1024];
  size_t          dn_size = sizeof(dn);
  char            serial[40];
  size_t          serial_size = sizeof(serial);
  time_t          expiret;
  time_t          activet;
  int             algo;
  unsigned int    bits;
  int             i;

  [str appendString: @"\n"];
  [str appendFormat: _(@"- Certificate info:\n")];

  expiret = gnutls_x509_crt_get_expiration_time(cert);
  activet = gnutls_x509_crt_get_activation_time(cert);
  [str appendFormat: _(@"- Certificate is valid since: %s"),
    ctime(&activet)];
  [str appendFormat: _(@"- Certificate expires: %s"),
    ctime (&expiret)];

#if 0
{
  char        digest[20];
  size_t      digest_size = sizeof(digest);
  if (gnutls_x509_fingerprint(GNUTLS_DIG_MD5,
    &cert_list[0], digest, &digest_size) >= 0)
    {
      [str appendString: _(@"- Certificate fingerprint: ")];
      for (i = 0; i < digest_size; i++)
        {
          [str appendFormat: @"%.2x ", (unsigned char)digest[i]];
        }
      [str appendString: @"\n"];
    }
}
#endif

  if (gnutls_x509_crt_get_serial(cert, serial, &serial_size) >= 0)
    {
      [str appendString: _(@"- Certificate serial number: ")];
      for (i = 0; i < serial_size; i++)
        {
          [str appendFormat: @"%.2x ", (unsigned char)serial[i]];
        }
      [str appendString: @"\n"];
    }

  [str appendString: _(@"- Certificate public key: ")];
  algo = gnutls_x509_crt_get_pk_algorithm(cert, &bits);
  if (GNUTLS_PK_RSA == algo)
    {
      [str appendString: _(@"RSA\n")];
      [str appendFormat: _(@"- Modulus: %d bits\n"), bits];
    }
  else if (GNUTLS_PK_DSA == algo)
    {
      [str appendString: _(@"DSA\n")];
      [str appendFormat: _(@"- Exponent: %d bits\n"), bits];
    }
  else
    {
      [str appendString: _(@"UNKNOWN\n")];
    }

  [str appendFormat: _(@"- Certificate version: #%d\n"),
    gnutls_x509_crt_get_version(cert)];

  dn_size = sizeof(dn);
  gnutls_x509_crt_get_dn(cert, dn, &dn_size);
  dn[dn_size - 1] = '\0';
  [str appendFormat: @"- Certificate DN: %@\n",
    [NSString stringWithUTF8String: dn]];

  dn_size = sizeof(dn);
  gnutls_x509_crt_get_issuer_dn(cert, dn, &dn_size);
  dn[dn_size - 1] = '\0';
  [str appendFormat: _(@"- Certificate Issuer's DN: %@\n"),
    [NSString stringWithUTF8String: dn]];
}
 
/* Method to purge older lists from cache.
 */
+ (void) housekeeping: (NSNotification*)n
{
  NSEnumerator          *enumerator;
  NSString              *key;
  NSTimeInterval        now;

  now = [NSDate timeIntervalSinceReferenceDate];
  [certificateListLock lock];
  enumerator = [[certificateListCache allKeys] objectEnumerator];
  while (nil != (key = [enumerator nextObject]))
    {
      GSTLSCertificateList      *list;

      list = [certificateListCache objectForKey: key];

      if (now - list->when > 300.0)
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
  f = [f stringByStandardizingPath];
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
      l->when = [NSDate timeIntervalSinceReferenceDate];
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

      if (count > 0)
        {
          time_t        now = (time_t)[[NSDate date] timeIntervalSince1970];
          unsigned int  i;

          for (i = 0; i < count; i++)
            {
              time_t    expiret = gnutls_x509_crt_get_expiration_time(crts[i]);
              time_t    activet = gnutls_x509_crt_get_activation_time(crts[i]);

              if (expiret <= now)
                {
                  NSLog(@"WARNING: at index %u in %@ ... expired at %s",
                    i, l->path, ctime(&activet));
                }
              if (activet > now)
                {
                  NSLog(@"WARNING: at index %u in %@ ... not valid until %s",
                    i, l->path, ctime(&activet));
                }
              if (expiret <= now || activet > now)
                {
                  NSMutableString       *m;

                  m = [NSMutableString stringWithCapacity: 2000];
                  [self certInfo: crts[i] to: m];
                  NSLog(@"%@", m);
                }
            }
        }

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
  NSEnumerator          *outer;
  NSString              *oKey;
  NSTimeInterval        now;

  now = [NSDate timeIntervalSinceReferenceDate];
  [privateKeyLock lock];
  outer = [[privateKeyCache0 allKeys] objectEnumerator];
  while (nil != (oKey = [outer nextObject]))
    {
      GSTLSPrivateKey   *key;

      key = [privateKeyCache0 objectForKey: oKey];
      if (now - key->when > 300.0)
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

          if (now - key->when > 300.0)
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
  f = [f stringByStandardizingPath];
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
      k->when = [NSDate timeIntervalSinceReferenceDate];
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


@implementation GSTLSCredentials

static NSLock                   *credentialsLock = nil;
static NSMutableDictionary      *credentialsCache = nil;

/* Method to purge older credentials from cache.
 */
+ (void) housekeeping: (NSNotification*)n
{
  NSEnumerator          *enumerator;
  NSDictionary          *key;
  NSTimeInterval        now;

  now = [NSDate timeIntervalSinceReferenceDate];
  [credentialsLock lock];
  enumerator = [[credentialsCache allKeys] objectEnumerator];
  while (nil != (key = [enumerator nextObject]))
    {
      GSTLSCredentials   *cred;

      cred = [credentialsCache objectForKey: key];
      if (now - cred->when > 300.0)
        {
          [credentialsCache removeObjectForKey: key];
        }
    }
  [credentialsLock unlock];
}

+ (void) initialize
{
  if (nil == credentialsLock)
    {
      credentialsLock = [NSLock new];
      credentialsCache = [NSMutableDictionary new];

      [[NSNotificationCenter defaultCenter] addObserver: self
	selector: @selector(housekeeping:)
	name: @"GSHousekeeping" object: nil];
    }
}

+ (GSTLSCredentials*) credentialsFromCAFile: (NSString*)ca
                              defaultCAFile: (NSString*)dca
                                 revokeFile: (NSString*)rv
                          defaultRevokeFile: (NSString*)drv
                            certificateFile: (NSString*)cf
                         certificateKeyFile: (NSString*)ck
                     certificateKeyPassword: (NSString*)cp
                                   asClient: (BOOL)client
                                      debug: (BOOL)debug
{
  GSTLSCredentials      *c;
  NSMutableString       *k;

  /* Build a unique key for the credentials based on all the
   * information (file names and password) used to build them.
   */
  k = [NSMutableString stringWithCapacity: 1024];
  ca = [ca stringByStandardizingPath];
  if (nil != ca) [k appendString: ca];
  [k appendString: @":"];
  if (nil != dca) [k appendString: dca];
  [k appendString: @":"];
  rv = [rv stringByStandardizingPath];
  if (nil != rv) [k appendString: rv];
  [k appendString: @":"];
  if (nil != drv) [k appendString: drv];
  [k appendString: @":"];
  if (nil != cf) [k appendString: cf];
  [k appendString: @":"];
  if (nil != ck) [k appendString: ck];
  [k appendString: @":"];
  if (nil != cp) [k appendString: cp];

  [credentialsLock lock];
  c = [credentialsCache objectForKey: k];
  if (nil != c)
    {
      [c retain];
      if (YES == debug)
        {
          NSLog(@"Re-used credentials %p for '%@'", c, k);
        }
    }
  [credentialsLock unlock];

  if (nil == c)
    {
      c = [self new];
      c->name = [k copy];
      c->when = [NSDate timeIntervalSinceReferenceDate];

      gnutls_certificate_allocate_credentials(&c->certcred);

      /* Set the default trusted authority certificates.
       */
      if ([dca length] > 0)
        {
          const char    *path;
          int           ret;

          path = [dca fileSystemRepresentation];
          ret = gnutls_certificate_set_x509_trust_file(c->certcred,
            path, GNUTLS_X509_FMT_PEM);
          if (ret < 0)
            {
              NSLog(@"Problem loading trusted authorities from %@: %s",
                dca, gnutls_strerror(ret));
            }
          else
            {
              if (ret > 0)
                {
                  c->trust = YES;   // Loaded at least one trusted CA
                }
              if (YES == debug)
                {
                  NSLog(@"Default trusted authorities (from %@): %d",
                   dca, ret);
                }
            }
        }

      /* Load any specified trusted authority certificates.
       */
      if ([ca length] > 0)
        {
          const char    *path;
          int           ret;

          path = [dca fileSystemRepresentation];
          ret = gnutls_certificate_set_x509_trust_file(c->certcred,
            path, GNUTLS_X509_FMT_PEM);
          if (ret < 0)
            {
              NSLog(@"Problem loading trusted authorities from %@: %s",
                ca, gnutls_strerror(ret));
            }
          else
            {
              if (ret > 0)
                {
                  c->trust = YES;
                }
              else if (0 == ret)
                {
                  NSLog(@"No certificates processed from %@", ca);
                }
              if (YES == debug)
                {
                  NSLog(@"Trusted authorities (from %@): %d", ca, ret);
                }
            }
        }

      /* Load default revocation list.
       */
      if ([drv length] > 0)
        {
          const char    *path;
          int           ret;

          path = [drv fileSystemRepresentation];
          ret = gnutls_certificate_set_x509_crl_file(c->certcred,
            path, GNUTLS_X509_FMT_PEM);
          if (ret < 0)
            {
              NSLog(@"Problem loading revocation list from %@: %s",
                drv, gnutls_strerror(ret));
            }
          else
            {
              if (YES == debug)
                {
                  NSLog(@"Default revocations (from %@): %d", drv, ret);
                }
            }
        }

      /* Load any specified revocation list.
       */
      if ([rv length] > 0)
        {
          const char    *path;
          int           ret;

          path = [rv fileSystemRepresentation];
          ret = gnutls_certificate_set_x509_crl_file(c->certcred,
            path, GNUTLS_X509_FMT_PEM);
          if (ret < 0)
            {
              NSLog(@"Problem loading revocation list from %@: %s",
                rv, gnutls_strerror(ret));
            }
          else
            {
              if (0 == ret)
                {
                  NSLog(@"No revocations processed from %@", rv);
                }
              if (YES == debug)
                {
                  NSLog(@"Revocations (from %@): %d", rv, ret);
                }
            }
        }

      /* Get the key for our sertificat .. if one is specified.
       */
      if (nil != ck)
        {
          c->key = [[GSTLSPrivateKey keyFromFile: ck
                                    withPassword: cp] retain];
          if (nil == c->key)
            {
              [c release];
              return nil;
            }
        }

      /* Load our certificate (may be a list) ifthe file is specified.
       */
      if (nil != cf)
        {
          c->list = [[GSTLSCertificateList listFromFile: cf] retain];
          if (nil == c->list)
            {
              [c release];
              return nil;
            }
        }

      /* If we have loaded a certificate, we add it to the credentials
       * using the certificate key so we can use it.
       */
      if (nil != c->list)
        {
          int   ret;

          ret = gnutls_certificate_set_x509_key(c->certcred,
            [c->list certificateList], [c->list count], [c->key key]);
          if (ret < 0)
            {
              NSLog(@"Unable to set certificate for session: %s",
                gnutls_strerror(ret));
              [c release];
              return nil;
            }
/*
          if (NO == client)
            {
                // FIXME ... if the server certificate required DH params ...
              c->dhParams = [[GSTLSDHParams current] retain];
              gnutls_certificate_set_dh_params(c->certcred,
                [c->dhParams params]);
            }
*/
        }

      if (YES == debug)
        {
          NSLog(@"Created credentials %p for '%@'", c, k);
        }
      [credentialsLock lock];
      [credentialsCache setObject: c forKey: c->name];
      [credentialsLock unlock];
    }

  return [c autorelease];
}

- (void) dealloc
{
  if (nil != key)
    {
      gnutls_certificate_free_credentials(certcred);
      DESTROY(key);
      DESTROY(list);
      DESTROY(dhParams);
      DESTROY(name);
    }
  [super dealloc];
}

- (gnutls_certificate_credentials_t) credentials
{
  return certcred;
}

- (BOOL) trust
{
  return trust;
}
@end




@implementation GSTLSSession

+ (GSTLSSession*) sessionWithOptions: (NSDictionary*)options
                           direction: (BOOL)isOutgoing
                           transport: (void*)handle
                                push: (GSTLSIOW)pushFunc
                                pull: (GSTLSIOR)pullFunc
{
  GSTLSSession  *sess;

  sess = [[self alloc] initWithOptions: options
                             direction: isOutgoing
                             transport: handle
                                  push: pushFunc
                                  pull: pullFunc];
  return [sess autorelease];
}

- (BOOL) active
{
   return active;
}

- (void) dealloc
{
  [self finalize];
  DESTROY(opts);
  DESTROY(credentials);
  DESTROY(problem);
  [super dealloc];
}

- (void) disconnect
{
  if (YES == active || YES == handshake)
    {
      active = NO;
      handshake = NO;
      gnutls_bye(session, GNUTLS_SHUT_RDWR);
    }
  if (YES == setup)
    {
      setup = NO;
      gnutls_db_remove_session(session);
      gnutls_deinit(session);
    }
}

- (void) finalize
{
  [self disconnect];
  [super finalize];
}

- (id) initWithOptions: (NSDictionary*)options
             direction: (BOOL)isOutgoing
             transport: (void*)handle
                  push: (GSTLSIOW)pushFunc
                  pull: (GSTLSIOR)pullFunc
{
  if (nil != (self = [super init]))
    {
      NSString  *ca;
      NSString  *dca;
      NSString  *rv;
      NSString  *drv;
      NSString  *cf;
      NSString  *ck;
      NSString  *cp;
      NSString  *pri;
      NSString  *str;
      BOOL      trust;
      BOOL      verify;

      opts = [options copy];
      outgoing = isOutgoing ? YES : NO;

      if (YES == outgoing)
        {
          verify = verifyServer;        // Verify connection to remote server
        }
      else
        {
          verify = verifyClient;        // Verify certificate of remote client
        }
      str = [opts objectForKey: GSTLSVerify];
      if (nil != str)
        {
          verify = [str boolValue];
        }

      debug = (globalDebug > 0) ? YES : NO;
      if (NO == debug)
        {
          debug = [[opts objectForKey: GSTLSDebug] boolValue];
        }

      /* Now initialise session and set it up.  It's simplest to always
       * allocate a credentials structure at this point (and get rid of
       * it when the session is disconnected) too.
       */
      if (YES == outgoing)
        {
          gnutls_init(&session, GNUTLS_CLIENT);
        }
      else
        {
          gnutls_init(&session, GNUTLS_SERVER);
          if (NO == verify)
            {
              /* We don't want to request/verify the client certificate,
               * so we mustn't ask the other end to send it.
               */
              gnutls_certificate_server_set_request(session,
                GNUTLS_CERT_IGNORE);
            }
        }
      setup = YES;
      trust = NO;

      ca = [opts objectForKey: GSTLSCAFile];
      dca = caFile;
      rv = [opts objectForKey: GSTLSRevokeFile];
      drv = revokeFile;
      cf = [opts objectForKey: GSTLSCertificateFile];
      ck = [opts objectForKey: GSTLSCertificateKeyFile];
      cp =  [opts objectForKey: GSTLSCertificateKeyPassword];

      credentials = [[GSTLSCredentials credentialsFromCAFile: ca
                                               defaultCAFile: dca
                                                  revokeFile: rv
                                           defaultRevokeFile: drv
                                             certificateFile: cf
                                          certificateKeyFile: ck
                                      certificateKeyPassword: cp
                                                    asClient: outgoing
                                                       debug: debug] retain];


      if (nil == credentials)
        {
          [self release];
          return nil;
        }

      trust = [credentials trust];
      if (YES == verify && NO == trust)
        {
          NSLog(@"You have requested that a TLS/SSL connection be to a remote"
            @" system with a verified certificate, but have provided no trusted"
            @" certificate authorities.");
          NSLog(@"If you did not use the GSTLSCAFile option to specify a file"
            @" containing certificate authorities for a session, and did not"
            @" specify a default file using the GSTLSCAFile user default or"    
            @" the GS_TLS_CA_FILE environment variable, then the system will"
            @" have attempted to use the GSTLS/ca-certificates.crt file in the"
            @" gnustep-base resource bundle.  Unfortunately, it has not been"
            @" possible to ready any trusted certificate authoritied from"
            @" these locations.");
        }

      gnutls_set_default_priority(session);

      pri = [opts objectForKey: NSStreamSocketSecurityLevelKey];
      str = [opts objectForKey: GSTLSPriority];
      if (nil == pri && nil == str)
        {
          str = priority;       // Default setting
        }
      if (YES == [str isEqual: @"SSLv3"])
        {
          pri = NSStreamSocketSecurityLevelSSLv3;
          str = nil;
        }
      else if (YES == [str isEqual: @"TLSv1"])
        {
          pri = NSStreamSocketSecurityLevelTLSv1;
          str = nil;
        }

      if (nil == str)
        {
          if ([pri isEqual: NSStreamSocketSecurityLevelNone] == YES)
            {
              // pri = NSStreamSocketSecurityLevelNone;
              GSOnceMLog(@"NSStreamSocketSecurityLevelNone is insecure ..."
                @" not implemented");
              DESTROY(self);
              return nil;
            }
          else if ([pri isEqual: NSStreamSocketSecurityLevelSSLv2] == YES)
            {
              // pri = NSStreamSocketSecurityLevelSSLv2;
              GSOnceMLog(@"NSStreamSocketSecurityLevelTLSv2 is insecure ..."
                @" not implemented");
              DESTROY(self);
              return nil;
            }
          else if ([pri isEqual: NSStreamSocketSecurityLevelSSLv3] == YES)
            {
#if GNUTLS_VERSION_NUMBER < 0x020C00
              const int proto_prio[2] = {
                GNUTLS_SSL3,
                0 };
              gnutls_protocol_set_priority(session, proto_prio);
#else
              gnutls_priority_set_direct(session,
                "NORMAL:-VERS-TLS-ALL:+VERS-SSL3.0", NULL);
#endif
            }
          else if ([pri isEqual: NSStreamSocketSecurityLevelTLSv1] == YES)
            {
#if GNUTLS_VERSION_NUMBER < 0x020C00
              const int proto_prio[4] = {
#if	defined(GNUTLS_TLS1_2)
                GNUTLS_TLS1_2,
#endif
                GNUTLS_TLS1_1,
                GNUTLS_TLS1_0,
                0 };
              gnutls_protocol_set_priority(session, proto_prio);
#else
              gnutls_priority_set_direct(session,
                "NORMAL:-VERS-SSL3.0:+VERS-TLS-ALL", NULL);
#endif
            }
        }
#if GNUTLS_VERSION_NUMBER >= 0x020C00
      else
        {
          gnutls_priority_set_direct(session, [str UTF8String], NULL);
        }
#endif

      /* Set certificate credentials for this session.
       */
      gnutls_credentials_set(session, GNUTLS_CRD_CERTIFICATE,
        [credentials credentials]);

      /* Set transport layer to use 
       */
#if GNUTLS_VERSION_NUMBER < 0x020C00
      gnutls_transport_set_lowat(session, 0);
#endif
      gnutls_transport_set_pull_function(session, pullFunc);
      gnutls_transport_set_push_function(session, pushFunc);
      gnutls_transport_set_ptr(session, (gnutls_transport_ptr_t)handle);
    }

  return self;
}

- (BOOL) handshake
{
  int   ret;

  if (YES == active || NO == setup)
    {
      return YES;       // Handshake completed or impossible.
    }

  handshake = YES;
  ret = gnutls_handshake(session);
  if (ret < 0)
    {
      if (gnutls_error_is_fatal(ret))
        {
          NSString      *p;

          p = [NSString stringWithFormat: @"%s", gnutls_strerror(ret)];

          /* We want to differentiate between errors which are usually
           * due to the remote end not expecting to be using TLS/SSL,
           * and errors which are caused by other interoperability
           * issues.  The first sort are not normally worth reporting.
           */
          if (GNUTLS_E_UNSUPPORTED_VERSION_PACKET == ret
            || GNUTLS_E_UNEXPECTED_PACKET_LENGTH == ret)
            {
              p = [p stringByAppendingString:
                @"\nmost often due to the remote end not expecting TLS/SSL"];
              ASSIGN(problem, p);
              if (YES == debug)
                {
                  NSLog(@"%@", p);
                }
            }
          else
            {
              ASSIGN(problem, p);
              NSLog(@"%@", p);
            }
          [self disconnect];
          return YES;   // Failed ... not active.
        }
      else
        {
          return NO;    // Non-fatal error needs a retry.
        }
    }
  else
    {
      NSString  *str;
      BOOL      shouldVerify = NO;

      active = YES;     // The TLS session is now active.
      handshake = NO;   // Handshake is over.

      if (YES == outgoing)
        {
          shouldVerify = verifyServer;  // Verify remote server certificate?
        }
      else
        {
          shouldVerify = verifyClient;  // Verify remote client certificate?
        }
      str = [opts objectForKey: GSTLSVerify];
      if (nil != str)
        {
          shouldVerify = [str boolValue];
        }

      if (globalDebug > 1)
        {
          NSLog(@"Before verify:\n%@", [self sessionInfo]);
        }
      if (YES == shouldVerify)
        {
          ret = [self verify];
          if (ret < 0)
            {
              if (globalDebug > 0
                || YES == [[opts objectForKey: GSTLSDebug] boolValue])
                {
                  NSLog(@"unable to verify SSL connection - %s",
                    gnutls_strerror(ret));
                  NSLog(@"%@", [self sessionInfo]);
                }
              [self disconnect];
            }
        }
      return YES;       // Handshake complete
    }
}

- (NSString*) problem
{
  return problem;
}

- (NSInteger) read: (void*)buf length: (NSUInteger)len
{
  return gnutls_record_recv(session, buf, len);
}

- (NSInteger) write: (const void*)buf length: (NSUInteger)len
{
  return gnutls_record_send(session, buf, len);
}

/* Copied/based on the public domain code provided by gnutls
 * to print the session ... I've left in details for features
 * we don't yet support.
 */
- (NSString*) sessionInfo
{
  NSMutableString               *str;
  const char                    *tmp;
  gnutls_credentials_type_t     cred;
  gnutls_kx_algorithm_t         kx;
  int                           dhe;
  int                           ecdh;

  dhe = ecdh = 0;
  str = [NSMutableString stringWithCapacity: 2000];

  /* get the key exchange's algorithm name
   */
  kx = gnutls_kx_get(session);
  tmp = gnutls_kx_get_name(kx);
  [str appendFormat: _(@"- Key Exchange: %s\n"), tmp];

  /* Check the authentication type used and switch to the appropriate.
   */
  cred = gnutls_auth_get_type(session);
  switch (cred)
    {
      case GNUTLS_CRD_IA:
        [str appendString: _(@"- TLS/IA session\n")];
        break;

      case GNUTLS_CRD_SRP:
#ifdef ENABLE_SRP
        [str appendFormat: _(@"- SRP session with username %s\n"),
          gnutls_srp_server_get_username(session)];
#endif
        break;

      case GNUTLS_CRD_PSK:
#if 0
        /* This returns NULL in server side.
         */
        if (gnutls_psk_client_get_hint(session) != NULL)
          {
            [str appendFormat: _(@"- PSK authentication. PSK hint '%s'\n"),
              gnutls_psk_client_get_hint(session)];
          }
        /* This returns NULL in client side.
         */
        if (gnutls_psk_server_get_username(session) != NULL)
          {
            [str appendFormat: _(@"- PSK authentication. Connected as '%s'\n"),
              gnutls_psk_server_get_username(session)];
          }

        if (GNUTLS_KX_ECDHE_PSK == kx)
          {
            dhe = 0;
            ecdh = 1;
          }
        else if (GNUTLS_KX_DHE_PSK == kx)
          {
            dhe = 1;
            ecdh = 0;
          }
#endif
        break;

      case GNUTLS_CRD_ANON:      /* anonymous authentication */
#if 0
        [str appendFormat: _(@"- Anonymous authentication.\n")];
        if (GNUTLS_KX_ANON_ECDH == kx)
          {
            dhe = 0;
            ecdh = 1;
          }
        else if (GNUTLS_KX_ANON_DH == kx)
          {
            dhe = 1;
            ecdh = 0;
          }
#endif
        break;

      case GNUTLS_CRD_CERTIFICATE:       /* certificate authentication */
      {
        unsigned int            cert_list_size = 0;
        const gnutls_datum_t    *cert_list;
        gnutls_x509_crt_t       cert;

        /* Check if we have been using ephemeral Diffie-Hellman.
         */
        if (GNUTLS_KX_DHE_RSA == kx || GNUTLS_KX_DHE_DSS == kx)
          {
            dhe = 1;
            ecdh = 0;
          }
#if 0
        if (GNUTLS_KX_ECDHE_RSA == kx || GNUTLS_KX_ECDHE_ECDSA == kx)
          {
            dhe = 0;
            ecdh = 1;
          }
#endif
        
        /* if the certificate list is available, then
         * print some information about it.
         */
        cert_list = gnutls_certificate_get_peers(session, &cert_list_size);
        if (cert_list_size > 0
          && gnutls_certificate_type_get(session) == GNUTLS_CRT_X509)
          {
            int cert_num;
        
            for (cert_num = 0; cert_num < cert_list_size; cert_num++)
              {
                gnutls_x509_crt_init(&cert);
                /* NB. the list of peer certificate is in memory in native
                 * format (DER) rather than the normal file format (PEM).
                 */
                gnutls_x509_crt_import(cert,
                  &cert_list[cert_num], GNUTLS_X509_FMT_DER);

                [str appendString: @"\n"];
                [str appendFormat: _(@"- Certificate %d info:\n"), cert_num];

                [GSTLSCertificateList certInfo: cert to: str];

                gnutls_x509_crt_deinit(cert);
              }
          }
      }
      break;
    }                           /* switch */

#if 0
  if (ecdh != 0)
    {
      [str appendFormat: _(@"- Ephemeral ECDH using curve %s\n"),
        gnutls_ecc_curve_get_name(gnutls_ecc_curve_get(session))];
    }
#endif
  if (dhe != 0)
    {
      [str appendFormat: _(@"- Ephemeral DH using prime of %d bits\n"),
        gnutls_dh_get_prime_bits(session)];
    }

  /* print the protocol's name (ie TLS 1.0) 
   */
  tmp = gnutls_protocol_get_name(gnutls_protocol_get_version(session));
  [str appendFormat: _(@"- Protocol: %s\n"), tmp];

  /* print the certificate type of the peer.
   * ie X.509
   */
  tmp = gnutls_certificate_type_get_name(gnutls_certificate_type_get(session));
  [str appendFormat: _(@"- Certificate Type: %s\n"), tmp];

  /* print the compression algorithm (if any)
   */
  tmp = gnutls_compression_get_name(gnutls_compression_get(session));
  [str appendFormat: _(@"- Compression: %s\n"), tmp];

  /* print the name of the cipher used.
   * ie 3DES.
   */
  tmp = gnutls_cipher_get_name(gnutls_cipher_get(session));
  [str appendFormat: _(@"- Cipher: %s\n"), tmp];

  /* Print the MAC algorithms name.
   * ie SHA1
   */
  tmp = gnutls_mac_get_name(gnutls_mac_get(session));
  [str appendFormat: _(@"- MAC: %s\n"), tmp];

  return str;
}

- (int) verify
{
  NSArray               *names;
  NSString              *str;
  unsigned int          status;
  const gnutls_datum_t  *cert_list;
  unsigned int          cert_list_size;
  int                   ret;
  gnutls_x509_crt_t     cert;

  /* This verification function uses the trusted CAs in the credentials
   * structure. So you must have installed one or more CA certificates.
   */
  ret = gnutls_certificate_verify_peers2 (session, &status);
  if (ret < 0)
    {
      NSLog(@"Error %s", gnutls_strerror(ret));
      return GNUTLS_E_CERTIFICATE_ERROR;
    }

  if (YES == debug)
    {
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
    }

  if (status & GNUTLS_CERT_INVALID)
    {
      NSLog(@"The remote certificate is not trusted.");
      return GNUTLS_E_CERTIFICATE_ERROR;
    }

  /* Up to here the process is the same for X.509 certificates and
   * OpenPGP keys. From now on X.509 certificates are assumed. This can
   * be easily extended to work with openpgp keys as well.
   */
  if (gnutls_certificate_type_get(session) != GNUTLS_CRT_X509)
    {
      NSLog(@"The remote certificate is not of the X509 type.");
      return GNUTLS_E_CERTIFICATE_ERROR;
    }

  if (gnutls_x509_crt_init(&cert) < 0)
    {
      NSLog(@"error in certificate initialization");
      return GNUTLS_E_CERTIFICATE_ERROR;
    }

  cert_list = gnutls_certificate_get_peers(session, &cert_list_size);
  if (cert_list == NULL)
    {
      NSLog(@"No certificate form remote end was found!");
      return GNUTLS_E_CERTIFICATE_ERROR;
    }

  if (gnutls_x509_crt_import(cert, &cert_list[0], GNUTLS_X509_FMT_DER) < 0)
    {
      NSLog(@"error parsing certificate");
      return GNUTLS_E_CERTIFICATE_ERROR;
    }

  str = [opts objectForKey: GSTLSRemoteHosts];
  if (nil == str)
    {
      names = nil;
    }
  else
    {
      /* The string is a comma separated list of permitted host names.
       */
      names = [str componentsSeparatedByString: @","];
    }

  if (nil != names)
    {
      NSEnumerator      *enumerator = [names objectEnumerator];
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
          NSLog(@"The certificate's owner does not match '%@'", names);
          gnutls_x509_crt_deinit(cert);
          return GNUTLS_E_CERTIFICATE_ERROR;
        }
    }

  gnutls_x509_crt_deinit(cert);

  return 0;     // Verified
}

@end

#endif


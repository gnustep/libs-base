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
NSString * const GSTLSCAVerify = @"GSTLSCAVerify";
NSString * const GSTLSRemoteHosts = @"GSTLSRemoteHosts";


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
 * The hard-coded value can be overridden by the GS_TLS_CA_FILE environment
 * variable, which in turn will be overridden by the GSTLSCAFile user
 * default string.
 */
static NSString *caFile = @"/etc/ssl/certs/ca-certificates.crt";

/* The verifyServer variable tells us if connections to a remote server should
 * (by default) verify its certificate against trusted authorities.
 * The hard-coded value can be overridden by the GS_TLS_CA_VERIFY environment
 * variable, which in turn will be overridden by the GSTLSCAVerify user
 * default string.
 * Any option set for a specific session overrides this default
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

static NSString *cipherList = nil;

static gnutls_anon_client_credentials_t anoncred;

/* This class is used to ensure that the GNUTLS system is initialised
 * and thread-safe.
 */
@implementation GSTLSObject

+ (void) _defaultsChanged: (NSNotification*)n
{
  NSString      *str;

  cipherList
    = [[NSUserDefaults standardUserDefaults] stringForKey: @"GSCipherList"];

  /* The GSTLSCAFile user default overrides the builtin value or the
   * GS_TLS_CA_FILE environment variable.
   */
  str = [[NSUserDefaults standardUserDefaults] stringForKey: GSTLSCAFile];
  if (nil != str)
    {
      ASSIGN(caFile, str);
    }

  str = [[NSUserDefaults standardUserDefaults] stringForKey: GSTLSCAVerify];
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
          NSUserDefaults	*defs;
          NSProcessInfo         *pi;
          NSString              *str;

          beenHere = YES;

          /* Let the GS_TLS_CA_FILE environment variable override the
           * default certificate authority location.
           */
          pi = [NSProcessInfo processInfo];
          str = [[pi environment] objectForKey: @"GS_TLS_CA_FILE"];
          if (nil != str)
            {
              ASSIGN(caFile, str);
            }

          str = [[pi environment] objectForKey: @"GS_TLS_CA_VERIFY"];
          if (nil != str)
            {
              verifyServer = [str boolValue];
            }

          str = [[pi environment] objectForKey: @"GS_TLS_DEBUG"];
          if (nil != str)
            {
              globalDebug = [str intValue];
            }

          defs = [NSUserDefaults standardUserDefaults];

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
  gnutls_dh_params_init(&p->params);
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

@implementation GSTLSSession

+ (GSTLSSession*) sessionWithOptions: (NSDictionary*)options
                           direction: (BOOL)isOutgoing
                           transport: (void*)handle
                                push: (GSTLSIOW)pushFunc
                                pull: (GSTLSIOR)pullFunc
                                host: (NSHost*)host
{
  GSTLSSession  *sess;

  sess = [[self alloc] initWithOptions: options
                             direction: isOutgoing
                             transport: handle
                                  push: pushFunc
                                  pull: pullFunc
                                  host: host];
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
  DESTROY(host);
  DESTROY(list);
  DESTROY(key);
  DESTROY(dhParams);
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
      gnutls_certificate_free_credentials(certcred);
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
                  host: (NSHost*)remote
{
  if (nil != (self = [super init]))
    {
      NSString  *certFile;
      NSString  *privateKey;
      NSString  *PEMpasswd;
      NSString  *pri;
      NSString  *str;
      int       ret;
      BOOL      debug = (globalDebug > 0) ? YES : NO;

      opts = [options copy];
      host = [remote copy];
      outgoing = isOutgoing ? YES : NO;

      if (NO == debug)
        {
          debug = [[opts objectForKey: GSTLSDebug] boolValue];
        }

      /* Now initialise session and set it up.  It's simplest to always
       * allocate a credentials structure at this point (and get rid of
       * it when the session is disconnected) too.
       */
      gnutls_certificate_allocate_credentials(&certcred);
      if (YES == outgoing)
        {
          gnutls_init(&session, GNUTLS_CLIENT);
        }
      else
        {
          gnutls_init(&session, GNUTLS_SERVER);

          /* We don't request any certificate from the client.
           * If we did we would need to verify it.
           */
          gnutls_certificate_server_set_request(session, GNUTLS_CERT_IGNORE);
        }
      setup = YES;

      /* Set the default trusted authority certificates.
       */
      if ([caFile length] > 0)
        {
          const char    *path = [caFile fileSystemRepresentation];
          int           ret;

          ret = gnutls_certificate_set_x509_trust_file(certcred,
            path, GNUTLS_X509_FMT_PEM);
          if (ret < 0)
            {
              NSLog(@"Problem loading trusted authorities from %@: %s",
                caFile, gnutls_strerror(ret));
            }
          else if (0 == ret && YES == debug)
            {
              NSLog(@"No certificates processed from %@", caFile);
            }
        }

      /* Load any specified trusted authority certificates.
       */
      str = [opts objectForKey: GSTLSCAFile];
      if ([str length] > 0)
        {
          const char    *path = [str fileSystemRepresentation];
          int           ret;

          ret = gnutls_certificate_set_x509_trust_file(certcred,
            path, GNUTLS_X509_FMT_PEM);
          if (ret < 0)
            {
              NSLog(@"Problem loading trusted authorities from %@: %s",
                str, gnutls_strerror(ret));
            }
          else if (0 == ret)
            {
              NSLog(@"No certificates processed from %@", str);
            }
        }

/*
      gnutls_certificate_set_x509_crl_file
        (certcred, "crl.pem", GNUTLS_X509_FMT_PEM);
      gnutls_certificate_set_verify_function(certcred,
        _verify_certificate_callback);

*/

      certFile = [opts objectForKey: GSTLSCertificateFile];
      privateKey = [opts objectForKey: GSTLSCertificateKeyFile];
      PEMpasswd = [opts objectForKey: GSTLSCertificateKeyPassword];

      if (nil != privateKey)
        {
          key = [[GSTLSPrivateKey keyFromFile: privateKey
                                 withPassword: PEMpasswd] retain];
          if (nil == key)
            {
              [self release];
              return nil;
            }
        }

      if (nil != certFile)
        {
          list = [[GSTLSCertificateList listFromFile: certFile] retain];
          if (nil == list)
            {
              [self release];
              return nil;
            }
        }

      if (nil != list)
        {
          ret = gnutls_certificate_set_x509_key(certcred,
            [list certificateList], [list count], [key key]);
          if (ret < 0)
            {
              NSLog(@"Unable to set certificate for session: %s",
                gnutls_strerror(ret));
              [self release];
              return nil;
            }
/*
          else if (NO == outgoing)
            {
              dhParams = [[GSTLSDHParams current] retain];
              gnutls_certificate_set_dh_params(certcred, [dhParams params]);
            }
*/
        }

      gnutls_set_default_priority(session);
      pri = [opts objectForKey: NSStreamSocketSecurityLevelKey];
      if ([pri isEqualToString: NSStreamSocketSecurityLevelNone] == YES)
        {
          // pri = NSStreamSocketSecurityLevelNone;
          GSOnceMLog(@"NSStreamSocketSecurityLevelNone is insecure ..."
            @" not implemented");
          DESTROY(self);
          return nil;
        }
      else if ([pri isEqualToString: NSStreamSocketSecurityLevelSSLv2] == YES)
        {
          // pri = NSStreamSocketSecurityLevelSSLv2;
          GSOnceMLog(@"NSStreamSocketSecurityLevelTLSv2 is insecure ..."
            @" not implemented");
          DESTROY(self);
          return nil;
        }
      else if ([pri isEqualToString: NSStreamSocketSecurityLevelSSLv3] == YES)
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
      else if ([pri isEqualToString: NSStreamSocketSecurityLevelTLSv1] == YES)
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

      /* Set certificate credentials for this session.
       */
      gnutls_credentials_set(session, GNUTLS_CRD_CERTIFICATE, certcred);

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
          NSLog(@"unable to make SSL connection: %s",
            gnutls_strerror(ret));
          [self disconnect];
          return YES;   // Failed ... not active.
        }
      else
        {
          if (GSDebugSet(@"NSStream") == YES)
            {
              gnutls_perror(ret);
            }
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
          shouldVerify = verifyServer;  // Verify remote server?
        }
      str = [opts objectForKey: GSTLSCAVerify];
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
        const gnutls_datum      *cert_list;
        gnutls_x509_crt         cert;

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
            char                dn[128];
            char                serial[40];
            size_t              dn_size = sizeof(dn);
            size_t              serial_size = sizeof(serial);
            time_t              expiret;
            time_t              activet;
            int                 algo;
            unsigned int        bits;
            int                 i;
            int                 cert_num;
        
            for (cert_num = 0; cert_num < cert_list_size; cert_num++)
              {
                gnutls_x509_crt_init(&cert);
                /* NB. the list of peer certificate is in memory in native
                 * format (DER) rather than the normal file format (PEM).
                 */
                gnutls_x509_crt_import(cert,
                  &cert_list[cert_num], GNUTLS_X509_FMT_DER);

                [str appendFormat: _(@"- Certificate %d info:\n"), cert_num];

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

                gnutls_x509_crt_get_dn(cert, dn, &dn_size);
                [str appendFormat: @"- Certificate DN: %s\n", dn];

                gnutls_x509_crt_get_issuer_dn(cert, dn, &dn_size);
                [str appendFormat: _(@"- Certificate Issuer's DN: %s\n"), dn];

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
  BOOL                  debug = (globalDebug > 0) ? YES : NO;
  NSArray               *names;
  NSString              *str;
  unsigned int          status;
  const gnutls_datum_t  *cert_list;
  unsigned int          cert_list_size;
  int                   ret;
  gnutls_x509_crt_t     cert;

  if (NO == debug)
    {
      debug = [[opts objectForKey: GSTLSDebug] boolValue];
    }

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
      /* No names specified ... use all known names for the host we are
       * connecting to.
       */
      names = [host names];
    }
  else if ([str length] == 0)
    {
      /* Empty name ... disable host name checking.
       */
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


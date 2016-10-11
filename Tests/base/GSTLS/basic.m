#import "ObjectTesting.h"
#import "../../../Headers/GNUstepBase/config.h"
#import "../../../Headers/Foundation/Foundation.h"
#ifdef HAVE_GNUTLS
#import "../../../Source/GSTLS.h"
#endif
int
main() {
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
START_SET("TLS support")
#ifdef HAVE_GNUTLS
#ifndef HAVE_GNUTLS_X509_PRIVKEY_IMPORT2
 testHopeful = YES;
#endif
 GSTLSPrivateKey *k  = [GSTLSPrivateKey keyFromFile: @"test.key" withPassword: @"asdf"]; 
  PASS(k != nil, "OpenSSL encrypted key can be loaded");
#else
  SKIP("TLS support disabled");
#endif
  END_SET("TLS support");
  DESTROY(arp);
  return 0;
}

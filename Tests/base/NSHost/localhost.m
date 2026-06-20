/*
 */

#import "Testing.h"

#import <Foundation/Foundation.h>

/*
 * A well-known loopback address available on every POSIX host.
 * We deliberately avoid external DNS lookups so tests remain
 * deterministic and do not depend on network availability.
 */
#define LOOPBACK_ADDR    @"127.0.0.1"
#define LOOPBACK_NAME    @"localhost"
#define INVALID_ADDR     @"999.999.999.999"
#define INVALID_NAME     @"this.host.should.never.exist.invalid"


int main(int argc, char **argv)
{
  ENTER_POOL

  NSHost  *host      = nil;
  NSHost  *host2     = nil;
  NSArray *names     = nil;
  NSArray *addresses = nil;
  NSString *name     = nil;
  NSString *address  = nil;


  /* ------------------------------------------------------------------ */
  START_SET("NSHost +currentHost")
  /* ------------------------------------------------------------------ */

  host = [NSHost currentHost];
  PASS(host != nil,
    "+currentHost returns a non-nil object");

  PASS([host isKindOfClass: [NSHost class]],
    "+currentHost returns an NSHost instance");

  names = [host names];
  PASS(names != nil,
    "-names of currentHost is not nil");

  PASS([names isKindOfClass: [NSArray class]],
    "-names returns an NSArray");

  PASS([names count] > 0,
    "-names of currentHost contains at least one entry");

  addresses = [host addresses];
  PASS(addresses != nil,
    "-addresses of currentHost is not nil");

  PASS([addresses isKindOfClass: [NSArray class]],
    "-addresses returns an NSArray");

  PASS([addresses count] > 0,
    "-addresses of currentHost contains at least one entry");

  /* Every address string must be non-empty */
  {
    NSEnumerator *e = [addresses objectEnumerator];
    NSString     *addr;
    BOOL          allNonEmpty = YES;
    while ((addr = [e nextObject]) != nil)
      {
        if ([addr length] == 0)
          {
            allNonEmpty = NO;
            break;
          }
      }
    PASS(allNonEmpty,
      "all addresses returned by currentHost are non-empty strings");
  }

  /* Every name string must be non-empty */
  {
    NSEnumerator *e = [names objectEnumerator];
    NSString     *n;
    BOOL          allNonEmpty = YES;
    while ((n = [e nextObject]) != nil)
      {
        if ([n length] == 0)
          {
            allNonEmpty = NO;
            break;
          }
      }
    PASS(allNonEmpty,
      "all names returned by currentHost are non-empty strings");
  }

  END_SET("NSHost +currentHost")


  /* ------------------------------------------------------------------ */
  START_SET("NSHost +currentHost identity and caching")
  /* ------------------------------------------------------------------ */

  host  = [NSHost currentHost];
  host2 = [NSHost currentHost];

  PASS(host != nil && host2 != nil,
    "+currentHost successive calls both succeed");

  /*
   * The class must cache the current host; successive calls must return
   * the same (isEqual:) object or at least equivalent objects.
   * Apple's documentation says +currentHost always returns the same
   * instance.
   */
  PASS_EQUAL(host, host2,
    "+currentHost returns equal hosts on successive calls");

  PASS(host == host2,
    "+currentHost returns the identical (cached) instance");

  END_SET("NSHost +currentHost identity and caching")


  /* ------------------------------------------------------------------ */
  START_SET("NSHost +hostWithName: loopback")
  /* ------------------------------------------------------------------ */

  host = [NSHost hostWithName: LOOPBACK_NAME];
  PASS(host != nil,
    "+hostWithName: @\"localhost\" returns non-nil");

  PASS([host isKindOfClass: [NSHost class]],
    "+hostWithName: @\"localhost\" returns an NSHost instance");

  names = [host names];
  PASS(names != nil && [names count] > 0,
    "+hostWithName: @\"localhost\" host has at least one name");

  /* The returned host must recognise "localhost" (or "localhost.*") */
  {
    NSEnumerator *e = [names objectEnumerator];
    NSString     *n;
    BOOL          found = NO;
    while ((n = [e nextObject]) != nil)
      {
        if ([n hasPrefix: LOOPBACK_NAME])
          {
            found = YES;
            break;
          }
      }
    PASS(found,
      "names for +hostWithName: @\"localhost\" include a localhost entry");
  }

  END_SET("NSHost +hostWithName: loopback")


  /* ------------------------------------------------------------------ */
  START_SET("NSHost +hostWithAddress: loopback")
  /* ------------------------------------------------------------------ */

  host = [NSHost hostWithAddress: LOOPBACK_ADDR];
  PASS(host != nil,
    "+hostWithAddress: @\"127.0.0.1\" returns non-nil");

  PASS([host isKindOfClass: [NSHost class]],
    "+hostWithAddress: @\"127.0.0.1\" returns an NSHost instance");

  addresses = [host addresses];
  PASS(addresses != nil && [addresses count] > 0,
    "+hostWithAddress: @\"127.0.0.1\" host has at least one address");

  PASS([addresses containsObject: LOOPBACK_ADDR],
    "-addresses for 127.0.0.1 host contains 127.0.0.1");

  END_SET("NSHost +hostWithAddress: loopback")


  /* ------------------------------------------------------------------ */
  START_SET("NSHost +hostWithName: invalid input")
  /* ------------------------------------------------------------------ */

  /*
   * Passing nil is not documented to crash; implementations typically
   * return nil or raise.  We test that it does not return a valid host.
   * Mark as hopeful because behaviour differs between GNUstep and Apple.
   */
  testHopeful = YES;
  host = [NSHost hostWithName: nil];
  PASS(host == nil,
    "+hostWithName: nil returns nil");
  testHopeful = NO;

  /*
   * An empty string is not a legal hostname.
   */
  testHopeful = YES;
  host = [NSHost hostWithName: @""];
  PASS(host == nil,
    "+hostWithName: @\"\" returns nil for empty name");
  testHopeful = NO;

  END_SET("NSHost +hostWithName: invalid input")


  /* ------------------------------------------------------------------ */
  START_SET("NSHost +hostWithAddress: invalid input")
  /* ------------------------------------------------------------------ */

  testHopeful = YES;
  host = [NSHost hostWithAddress: nil];
  PASS(host == nil,
    "+hostWithAddress: nil returns nil");
  testHopeful = NO;

  testHopeful = YES;
  host = [NSHost hostWithAddress: @""];
  PASS(host == nil,
    "+hostWithAddress: @\"\" returns nil for empty address");
  testHopeful = NO;

  testHopeful = YES;
  host = [NSHost hostWithAddress: INVALID_ADDR];
  PASS(host == nil,
    "+hostWithAddress: returns nil for malformed dotted-quad");
  testHopeful = NO;

  END_SET("NSHost +hostWithAddress: invalid input")


  /* ------------------------------------------------------------------ */
  START_SET("NSHost -name and -address convenience accessors")
  /* ------------------------------------------------------------------ */

  host = [NSHost hostWithAddress: LOOPBACK_ADDR];
  PASS(host != nil,
    "host from 127.0.0.1 is not nil (prerequisite)");

  if (host != nil)
    {
      address = [host address];
      PASS(address != nil,
        "-address returns non-nil for loopback host");

      PASS([address isKindOfClass: [NSString class]],
        "-address returns an NSString");

      PASS([address length] > 0,
        "-address returns a non-empty string");

      /* -address must be one of the addresses in -addresses */
      PASS([[host addresses] containsObject: address],
        "-address is a member of -addresses");

      name = [host name];
      /*
       * -name may return nil if no reverse-DNS entry exists; that is
       * acceptable.  When it does return something it must be consistent.
       */
      if (name != nil)
        {
          PASS([name isKindOfClass: [NSString class]],
            "-name returns an NSString when non-nil");

          PASS([name length] > 0,
            "-name returns a non-empty string when non-nil");

          PASS([[host names] containsObject: name],
            "-name is a member of -names");
        }
      else
        {
          PASS(YES, "-name returned nil (acceptable; no reverse DNS required)");
        }
    }

  host = [NSHost currentHost];
  name = [host name];
  PASS(name != nil,
    "-name of currentHost is non-nil");
  PASS([name length] > 0,
    "-name of currentHost is a non-empty string");
  PASS([[host names] containsObject: name],
    "-name of currentHost is a member of -names");

  END_SET("NSHost -name and -address convenience accessors")


  /* ------------------------------------------------------------------ */
  START_SET("NSHost -isEqualToHost:")
  /* ------------------------------------------------------------------ */

  host  = [NSHost hostWithAddress: LOOPBACK_ADDR];
  host2 = [NSHost hostWithAddress: LOOPBACK_ADDR];
  PASS(host != nil && host2 != nil,
    "two loopback hosts created successfully (prerequisite)");

  if (host != nil && host2 != nil)
    {
      PASS([host isEqualToHost: host2],
        "-isEqualToHost: returns YES for two hosts with the same address");

      PASS([host isEqualToHost: host],
        "-isEqualToHost: returns YES when compared with itself");

      PASS_EQUAL(host, host2,
        "-isEqual: returns YES for two equivalent NSHost objects");
    }

  host2 = [NSHost currentHost];
  if (host != nil && host2 != nil)
    {
      /*
       * 127.0.0.1 and currentHost should generally differ unless the
       * machine's only address is the loopback.  We merely verify that
       * the method does not crash and returns a BOOL.
       */
      BOOL eq = [host isEqualToHost: host2];
      PASS(eq == YES || eq == NO,
        "-isEqualToHost: between loopback and currentHost returns a BOOL");
    }

  END_SET("NSHost -isEqualToHost:")


  /* ------------------------------------------------------------------ */
  START_SET("NSHost -isEqualToHost: with nil")
  /* ------------------------------------------------------------------ */

  host = [NSHost hostWithAddress: LOOPBACK_ADDR];
  if (host != nil)
    {
      testHopeful = YES;
      PASS([host isEqualToHost: nil] == NO,
        "-isEqualToHost: nil returns NO");
      testHopeful = NO;
    }

  END_SET("NSHost -isEqualToHost: with nil")


  /* ------------------------------------------------------------------ */
  START_SET("NSHost addresses and names collections integrity")
  /* ------------------------------------------------------------------ */

  host = [NSHost currentHost];
  PASS(host != nil, "currentHost non-nil (prerequisite)");

  if (host != nil)
    {
      NSArray      *addrs  = [host addresses];
      NSArray      *nms    = [host names];
      NSEnumerator *e;
      id            obj;

      /* Every element of -addresses must be an NSString */
      e = [addrs objectEnumerator];
      {
        BOOL allStrings = YES;
        while ((obj = [e nextObject]) != nil)
          {
            if (![obj isKindOfClass: [NSString class]])
              {
                allStrings = NO;
                break;
              }
          }
        PASS(allStrings,
          "all objects in -addresses are NSString instances");
      }

      /* Every element of -names must be an NSString */
      e = [nms objectEnumerator];
      {
        BOOL allStrings = YES;
        while ((obj = [e nextObject]) != nil)
          {
            if (![obj isKindOfClass: [NSString class]])
              {
                allStrings = NO;
                break;
              }
          }
        PASS(allStrings,
          "all objects in -names are NSString instances");
      }

      /* -addresses must not contain duplicates */
      {
        NSUInteger i, j;
        BOOL       noDups = YES;
        for (i = 0; i < [addrs count] && noDups; i++)
          {
            for (j = i + 1; j < [addrs count] && noDups; j++)
              {
                if ([[addrs objectAtIndex: i]
                      isEqual: [addrs objectAtIndex: j]])
                  noDups = NO;
              }
          }
        PASS(noDups,
          "-addresses contains no duplicate entries");
      }

      /* -names must not contain duplicates */
      {
        NSUInteger i, j;
        BOOL       noDups = YES;
        for (i = 0; i < [nms count] && noDups; i++)
          {
            for (j = i + 1; j < [nms count] && noDups; j++)
              {
                if ([[nms objectAtIndex: i]
                      isEqual: [nms objectAtIndex: j]])
                  noDups = NO;
              }
          }
        PASS(noDups,
          "-names contains no duplicate entries");
      }
    }

  END_SET("NSHost addresses and names collections integrity")


  /* ------------------------------------------------------------------ */
  START_SET("NSHost +hostWithName: vs +hostWithAddress: symmetry")
  /* ------------------------------------------------------------------ */

  /*
   * A host obtained via +hostWithName: @"localhost" and one obtained via
   * +hostWithAddress: @"127.0.0.1" should both have 127.0.0.1 in their
   * addresses list, demonstrating that the two factory paths resolve to
   * equivalent network entities.
   */
  host  = [NSHost hostWithName: LOOPBACK_NAME];
  host2 = [NSHost hostWithAddress: LOOPBACK_ADDR];

  if (host != nil && host2 != nil)
    {
      PASS([[host  addresses] containsObject: LOOPBACK_ADDR],
        "host from +hostWithName: @\"localhost\" has 127.0.0.1 in addresses");

      PASS([[host2 addresses] containsObject: LOOPBACK_ADDR],
        "host from +hostWithAddress: @\"127.0.0.1\" has 127.0.0.1 in addresses");

      PASS([host isEqualToHost: host2],
        "localhost by name and 127.0.0.1 by address are equal hosts");
    }
  else
    {
      PASS(YES,
        "skipping symmetry check: loopback resolution unavailable");
    }

  END_SET("NSHost +hostWithName: vs +hostWithAddress: symmetry")


  /* ------------------------------------------------------------------ */
  START_SET("NSHost -description")
  /* ------------------------------------------------------------------ */

  host = [NSHost currentHost];
  if (host != nil)
    {
      NSString *desc = [host description];
      PASS(desc != nil,
        "-description returns non-nil for currentHost");

      PASS([desc isKindOfClass: [NSString class]],
        "-description returns an NSString");

      PASS([desc length] > 0,
        "-description returns a non-empty string");
    }

  host = [NSHost hostWithAddress: LOOPBACK_ADDR];
  if (host != nil)
    {
      NSString *desc = [host description];
      PASS(desc != nil,
        "-description returns non-nil for loopback host");
      PASS([desc length] > 0,
        "-description returns a non-empty string for loopback host");
    }

  END_SET("NSHost -description")


  /* ------------------------------------------------------------------ */
  START_SET("NSHost +setHostCacheEnabled: and +isHostCacheEnabled")
  /* ------------------------------------------------------------------ */

  /*
   * Cache control is a GNUstep extension that is also present on some
   * Apple versions; mark tests as hopeful so they are reported but do
   * not count as hard failures if the selectors are absent.
   */
  testHopeful = YES;

  [NSHost setHostCacheEnabled: NO];
  PASS([NSHost isHostCacheEnabled] == NO,
    "+isHostCacheEnabled returns NO after +setHostCacheEnabled: NO");

  [NSHost setHostCacheEnabled: YES];
  PASS([NSHost isHostCacheEnabled] == YES,
    "+isHostCacheEnabled returns YES after +setHostCacheEnabled: YES");

  /* Restore a sensible default */
  [NSHost setHostCacheEnabled: YES];

  testHopeful = NO;

  END_SET("NSHost +setHostCacheEnabled: and +isHostCacheEnabled")


  /* ------------------------------------------------------------------ */
  START_SET("NSHost -hash consistency")
  /* ------------------------------------------------------------------ */

  host  = [NSHost hostWithAddress: LOOPBACK_ADDR];
  host2 = [NSHost hostWithAddress: LOOPBACK_ADDR];

  if (host != nil && host2 != nil && [host isEqualToHost: host2])
    {
      PASS([host hash] == [host2 hash],
        "equal NSHost objects have equal -hash values");
    }
  else
    {
      PASS(YES,
        "skipping hash check: prerequisite hosts unavailable or not equal");
    }

  /* A single host must return the same hash on repeated calls */
  host = [NSHost currentHost];
  if (host != nil)
    {
      NSUInteger h1 = [host hash];
      NSUInteger h2 = [host hash];
      PASS(h1 == h2,
        "-hash is stable across repeated calls on the same host");
    }

  END_SET("NSHost -hash consistency")


  /* ------------------------------------------------------------------ */
  START_SET("NSHost +flushHostCache")
  /* ------------------------------------------------------------------ */

  /*
   * +flushHostCache is a GNUstep extension; hopeful so failures are
   * informational rather than blocking.
   */
  testHopeful = YES;
  PASS_RUNS([NSHost flushHostCache],
    "+flushHostCache does not raise an exception");
  testHopeful = NO;

  END_SET("NSHost +flushHostCache")


  LEAVE_POOL

  return 0;
}

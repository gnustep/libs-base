/* NSGeometry tests */
#import <Foundation/Foundation.h>
#import "Testing.h"

static BOOL	MacOSXCompatibleGeometry()
{
#if (__APPLE__ && !defined(GNUSTEP_BASE_LIBRARY))
  return YES;
#else
  NSUserDefaults *dflt = [NSUserDefaults standardUserDefaults];
  if ([dflt boolForKey: @"GSOldStyleGeometry"] == YES)
    return NO;
  return [dflt boolForKey: @"GSMacOSXCompatible"];
#endif
}


int main()
{ 
  START_SET("NSGeometry GSMacOSXCompatible")
  NSUserDefaults	*dflt = [NSUserDefaults standardUserDefaults];
  BOOL 			compat_mode = MacOSXCompatibleGeometry();
  NSPoint 		p, p2;
  NSRect 		r, r2;
  NSSize 		s, s2;
  NSString 		*sp;
  NSString		*sr;
  NSString		*ss;
  
  p = NSMakePoint(23.45, -3.45);
  s = NSMakeSize(0.5, 0.22);
  r = NSMakeRect(23.45, -3.45, 2044.3, 2033);

#if defined(GNUSTEP_BASE_LIBRARY)
  if (compat_mode)
    {
      [dflt setBool: NO forKey: @"GSMacOSXCompatible"];
    }
  PASS((MacOSXCompatibleGeometry() == NO), 
       "Not in MacOSX geometry compat mode");

  sp = NSStringFromPoint(p);
  p2 = NSPointFromString(sp);
  PASS((EQ(p2.x, p.x) && EQ(p2.y, p.y)), 
       "Can read output of NSStringFromPoint");

  sr = NSStringFromRect(r);
  r2 = NSRectFromString(sr);
  PASS((EQ(r2.origin.x, r.origin.x) && EQ(r2.origin.y, r.origin.y)
    && EQ(r2.size.width, r.size.width) && EQ(r2.size.height, r.size.height)), 
    "Can read output of NSStringFromRect")

  ss = NSStringFromSize(s);
  s2 = NSSizeFromString(ss);
  PASS((EQ(s2.width, s.width) && EQ(s2.height, s.height)), 
    "Can read output of NSStringFromSize")

  [dflt setBool: YES forKey: @"GSMacOSXCompatible"];
  PASS((MacOSXCompatibleGeometry() == YES), "In MacOSX geometry compat mode")
#endif

  sp = NSStringFromPoint(p);
  p2 = NSPointFromString(sp);
  PASS((EQ(p2.x, p.x) && EQ(p2.y, p.y)), 
    "Can read output of NSStringFromPoint (MacOSX compat)")

  sr = NSStringFromRect(r);
  r2 = NSRectFromString(sr);
  PASS((EQ(r2.origin.x, r.origin.x) && EQ(r2.origin.y, r.origin.y)
    && EQ(r2.size.width, r.size.width) && EQ(r2.size.height, r.size.height)), 
    "Can read output of NSStringFromRect (MacOSX compat)")

  ss = NSStringFromSize(s);
  s2 = NSSizeFromString(ss);
  PASS((EQ(s2.width, s.width) && EQ(s2.height, s.height)), 
    "Can read output of NSStringFromSize (MacOSX compat)")

#if defined(GNUSTEP_BASE_LIBRARY)
  if (compat_mode != MacOSXCompatibleGeometry())
    {
      [dflt setBool: NO forKey: @"GSMacOSXCompatible"];
    }
#endif

  END_SET("NSGeometry GSMacOSXCompatible")

  return 0;
}

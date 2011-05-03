/** Implementation of GNUSTEP key value observing
   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 2005

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   $Date$ $Revision$
*/

#include "GNUstepBase/preface.h"
#include "Foundation/NSObject.h"
#include "Foundation/NSCharacterSet.h"
#include "Foundation/NSString.h"
#include "Foundation/NSException.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSMapTable.h"
#include "Foundation/NSMethodSignature.h"
#include "Foundation/NSKeyValueCoding.h"
#include "Foundation/NSKeyValueObserving.h"
#include "Foundation/NSSet.h"
#include "GNUstepBase/GSObjCRuntime.h"
#include "GNUstepBase/Unicode.h"
#include "GNUstepBase/GSLock.h"

/*
 * IMPLEMENTATION NOTES
 *
 * Originally, I wanted to do KVO via a proxy, with isa swizzling
 * to turn the original instance into an instance of the proxy class.
 * However, I couldn't figure a way to get decent performance out of
 * this model, as every message to the instance would have to be
 * forwarded through the proxy class methods to the original class
 * methods.
 *
 * So, instead I arrived at the mechanism of creating a subclass of
 * each class being observed, with a few subclass methods overriding
 * those of the original, but most remaining the same.
 * The same isa swizzling technique was used to convert between the
 * original class and the superclass.
 * This subclass basically overrides several standard methods with
 * those from a template class, and then overrides any setter methods
 * with a another generic setter.
 */

NSString *const NSKeyValueChangeIndexesKey
  = @"NSKeyValueChangeIndexesKey";
NSString *const NSKeyValueChangeKindKey
  = @"NSKeyValueChangeKindKey";
NSString *const NSKeyValueChangeNewKey
  = @"NSKeyValueChangeNewKey";
NSString *const NSKeyValueChangeOldKey
  = @"NSKeyValueChangeOldKey";

static const char	*dummy = "";

static NSRecursiveLock	*kvoLock = nil;
static NSMapTable	*classTable = 0;
static NSMapTable	*infoTable = 0;
static Class		baseClass;

/*
 * This is the template class whose methods are added to KVO classes to
 * override the originals and make the swizzled class look like the
 * original class.
 */
@interface	GSKVOBase : NSObject
@end

/*
 * This is a placeholder class which has the abstract setter method used
 * to replace all setter methods in the original.  In fact we need different
 * setter methods for different arguments ... but right now we just have
 * one for objects.
 */
@interface	GSKVOSetter : NSObject
- (void) setter: (void*)val;
- (void) setterChar: (unsigned char)val;
- (void) setterDouble: (double)val;
- (void) setterFloat: (float)val;
- (void) setterInt: (unsigned int)val;
- (void) setterLong: (unsigned long)val;
#ifdef  _C_LNG_LNG
- (void) setterLongLong: (unsigned long long)val;
#endif
- (void) setterShort: (unsigned short)val;
@end

/*
 * Instances of this class are created to hold information about the
 * observers monitoring a particular object which is being observed.
 */
@interface	GSKVOInfo : NSObject
{
  NSObject	*instance;	// Not retained.
  NSLock	*iLock;
  NSMapTable	*paths;
}
- (void) changeForKey: (NSString*)aKey;
- (id) initWithInstance: (NSObject*)i;
- (BOOL) isUnobserved;
@end



@implementation	GSKVOBase

- (void) dealloc
{
  // Turn off KVO for self ... then call the real dealloc implementation.
  [self setObservationInfo: nil];
  isa = [self class];
  [self dealloc];
  GSNOSUPERDEALLOC;
}

- (Class) class
{
  return GSObjCSuper(GSObjCClass(self));
}

- (void) setValue: (id)anObject forKey: (NSString*)aKey
{
  if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
      [self willChangeValueForKey: aKey];
      [super setValue: anObject forKey: aKey];
      [self didChangeValueForKey: aKey];
    }
  else
    {
      [super setValue: anObject forKey: aKey];
    }
}

- (void) setValue: (id)anObject forKeyPath: (NSString*)aKey
{
  if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
      [self willChangeValueForKey: aKey];
      [super setValue: anObject forKeyPath: aKey];
      [self didChangeValueForKey: aKey];
    }
  else
    {
      [super setValue: anObject forKeyPath: aKey];
    }
}

- (void) takeStoredValue: (id)anObject forKey: (NSString*)aKey
{
  if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
      [self willChangeValueForKey: aKey];
      [super takeStoredValue: anObject forKey: aKey];
      [self didChangeValueForKey: aKey];
    }
  else
    {
      [super takeStoredValue: anObject forKey: aKey];
    }
}

- (void) takeValue: (id)anObject forKey: (NSString*)aKey
{
  if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
      [self willChangeValueForKey: aKey];
      [super takeValue: anObject forKey: aKey];
      [self didChangeValueForKey: aKey];
    }
  else
    {
      [super takeValue: anObject forKey: aKey];
    }
}

- (void) takeValue: (id)anObject forKeyPath: (NSString*)aKey
{
  if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
      [self willChangeValueForKey: aKey];
      [super takeValue: anObject forKeyPath: aKey];
      [self didChangeValueForKey: aKey];
    }
  else
    {
      [super takeValue: anObject forKeyPath: aKey];
    }
}

- (Class) superclass
{
  return GSObjCSuper(GSObjCSuper(GSObjCClass(self)));
}
@end

/*
 * Get a key name from a selector (setKey: or _setKey:) by
 * taking the key part and making the first letter lowercase.
 */
static NSString *newKey(SEL _cmd)
{
  const char	*name = GSNameFromSelector(_cmd);
  unsigned	len = strlen(name);
  NSString	*key;
  unsigned	i;

  if (*name == '_')
    {
      name++;
      len--;
    }
  name += 3;			// Step past 'set'
  len -= 4;			// allow for 'set' and trailing ':'
  for (i = 0; i < len; i++)
    {
      if (name[i] < 0)
	{
	  break;
	}
    }
  if (i == len)
    {
      char	buf[len];

      /* Efficient key creation for ascii keys
       */
      for (i = 0; i < len; i++) buf[i] = name[i];
      if (isupper(buf[0]))
	{
	  buf[0] = tolower(buf[0]);
	}
      key = [[NSString alloc] initWithBytes: buf
				     length: len
				   encoding: NSASCIIStringEncoding];
    }
  else
    {
      unichar		u;
      NSMutableString	*m;
      NSString		*tmp;

      /*
       * Key creation for unicode strings.
       */
      m = [[NSMutableString alloc] initWithBytes: name
					  length: len
					encoding: NSUTF8StringEncoding];
      u = [m characterAtIndex: 0];
      u = uni_tolower(u);
      tmp = [[NSString alloc] initWithCharacters: &u length: 1];
      [m replaceCharactersInRange: NSMakeRange(0, 1) withString: tmp];
      RELEASE(tmp);
      key = m;
    }
  return key;
}

/*
 * This class
 */
@implementation	GSKVOSetter
- (void) setter: (void*)val
{
  NSString	*key;
  Class		c = [self class];
  void		(*imp)(id,SEL,void*);

  imp = (void (*)(id,SEL,void*))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}

- (void) setterChar: (unsigned char)val
{
  NSString	*key;
  Class		c = [self class];
  void		(*imp)(id,SEL,unsigned char);

  imp = (void (*)(id,SEL,unsigned char))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}

- (void) setterDouble: (double)val
{
  NSString	*key;
  Class		c = [self class];
  void		(*imp)(id,SEL,double);

  imp = (void (*)(id,SEL,double))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}

- (void) setterFloat: (float)val
{
  NSString	*key;
  Class		c = [self class];
  void		(*imp)(id,SEL,float);

  imp = (void (*)(id,SEL,float))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}

- (void) setterInt: (unsigned int)val
{
  NSString	*key;
  Class		c = [self class];
  void		(*imp)(id,SEL,unsigned int);

  imp = (void (*)(id,SEL,unsigned int))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}

- (void) setterLong: (unsigned long)val
{
  NSString	*key;
  Class		c = [self class];
  void		(*imp)(id,SEL,unsigned long);

  imp = (void (*)(id,SEL,unsigned long))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}

#ifdef  _C_LNG_LNG
- (void) setterLongLong: (unsigned long long)val
{
  NSString	*key;
  Class		c = [self class];
  void		(*imp)(id,SEL,unsigned long long);

  imp = (void (*)(id,SEL,unsigned long long))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}
#endif

- (void) setterShort: (unsigned short)val
{
  NSString	*key;
  Class		c = [self class];
  void		(*imp)(id,SEL,unsigned short);

  imp = (void (*)(id,SEL,unsigned short))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}
@end


@implementation	GSKVOInfo
- (void) addObserver: (NSObject*)anObserver
	  forKeyPath: (NSString*)aPath
	     options: (NSKeyValueObservingOptions)options
	     context: (void*)aContext
{
  NSMapTable	*observers;

  [iLock lock];
  observers = (NSMapTable*)NSMapGet(paths, (void*)aPath);
  if (observers == 0)
    {
      observers = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
	NSNonOwnedPointerMapValueCallBacks, 8);
      // use immutable object for map key
      aPath = [aPath copy];
      NSMapInsert(paths, (void*)aPath, (void*)observers);
      RELEASE(aPath);
    }
  /*
   * FIXME ... should store an object containing context and options.
   * For simplicity right now, just store context or a dummy value.
   */
  NSMapInsert(observers, (void*)anObserver, aContext == 0 ? dummy : aContext);
  [iLock unlock];
}

- (void) dealloc
{
  if (paths != 0) NSFreeMapTable(paths);
  RELEASE(iLock);
  [super dealloc];
}

- (void) changeForKey: (NSString*)aKey
{
  NSMapTable		*observers;

  [iLock lock];
  observers = (NSMapTable*)NSMapGet(paths, (void*)aKey);
  if (observers != 0)
    {
      NSMapEnumerator	enumerator;
      NSObject		*observer;
      void		*context;

      enumerator = NSEnumerateMapTable(observers);
      while (NSNextMapEnumeratorPair(&enumerator,
	(void **)(&observer), &context))
	{
	  if (context == dummy) context = 0;

	  if ([observer respondsToSelector:
	    @selector(observeValueForKeyPath:ofObject:change:context:)])
	    {
	      [observer observeValueForKeyPath: aKey
				      ofObject: instance
					change: nil
				       context: context];
	    }
	}
      NSEndMapTableEnumeration(&enumerator);
    }
  [iLock unlock];
}

- (id) initWithInstance: (NSObject*)i
{
  instance = i;
  paths = NSCreateMapTable(NSObjectMapKeyCallBacks,
    NSNonOwnedPointerMapValueCallBacks, 8);
  iLock = [GSLazyRecursiveLock new];
  return self;
}

- (BOOL) isUnobserved
{
  BOOL	result = NO;

  [iLock lock];
  if (NSCountMapTable(paths) == 0)
    {
      result = YES;
    }
  [iLock unlock];
  return result;
}

- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath
{
  NSMapTable	*observers;

  [iLock lock];
  observers = (NSMapTable*)NSMapGet(paths, (void*)aPath);
  if (observers != 0)
    {
      void	*context = NSMapGet(observers, (void*)anObserver);

      if (context != 0)
	{
	  NSMapRemove(observers, (void*)anObserver);
	  if (NSCountMapTable(observers) == 0)
	    {
	      NSMapRemove(paths, (void*)aPath);
	    }
	}
    }
  [iLock unlock];
}
@end


static inline void setup()
{
  if (kvoLock == nil)
    {
      kvoLock = [GSLazyRecursiveLock new];
      classTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
	NSNonOwnedPointerMapValueCallBacks, 128);
      infoTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
	NSNonOwnedPointerMapValueCallBacks, 1024);
      baseClass = NSClassFromString(@"GSKVOBase");
    }
}

static Class classForInstance(id o)
{
  Class c = GSObjCClass(o);
  Class	p;

  setup();

  [kvoLock lock];
  p = (Class)NSMapGet(classTable, (void*)c);
  if (p == 0)
    {
      NSValue		*template;
      NSString		*superName;
      NSString		*name;
      NSArray		*methods;
      NSMutableArray	*setters;
      unsigned		count;
      NSCharacterSet	*lc = [NSCharacterSet lowercaseLetterCharacterSet];

      /*
       * Create subclass of the original, and override some methods
       * with implementations from our abstract base class.
       */
      superName = NSStringFromClass(c);
      name = [@"GSKVO" stringByAppendingString: superName];
      template = GSObjCMakeClass(name, superName, nil);
      GSObjCAddClasses([NSArray arrayWithObject: template]);
      p = NSClassFromString(name);
      GSObjCAddClassBehavior(p, baseClass);

      /*
       * Get the names of all setter methods set(Key): or _set(Key):
       */
      methods = GSObjCMethodNames(o);
      count = [methods count];
      setters = [NSMutableArray arrayWithCapacity: count];
      while (count-- > 0)
	{
	  NSRange	r;
	  int		x = 3;

	  name = [methods objectAtIndex: count];
	  r = [name rangeOfString: @":"];
	  if (r.length > 0 && r.location == [name length]-1
	    && ([name hasPrefix: @"set"] || [name hasPrefix: @"_set"]))
	    {
	      unichar	u = [name characterAtIndex: x];

	      /*
	       * If the key name part begins with a lowercase letter,
	       * this is not a setter method.
	       */
	      if ([lc characterIsMember: u] == NO)
		{
		  /*
		   * Don't override setObservationInfo: ... it's a special
		   * case.
		   */
		  if ([name isEqualToString: @"setObservationInfo:"] == NO)
		    {
		      [setters addObject: name];
		    }
		}
	    }
	}
      count = [setters count];

      if (count > 0)
	{
	  GSMethodList	m;

	  /*
	   * The original class contains setter methods ... so we must
	   * replace them all with our own version which does KVO
	   * notifications.
	   */
	  m = GSAllocMethodList(count);
	  while (count-- > 0)
	    {
	      NSMethodSignature	*sig;
	      SEL		sel;
	      IMP		imp;
	      const char	*type;

	      name = [setters objectAtIndex: count];
	      sel = NSSelectorFromString(name);
	      sig = [o methodSignatureForSelector: sel];

	      /*
	       * A setter must take three arguments (self, _cmd, value)
	       * and return nothing.
	       */
	      if (*[sig methodReturnType] != _C_VOID
		|| [sig numberOfArguments] != 3)
		{
		  continue;	// Not a valid setter method.
		}

	      /*
	       * Since the compiler passes different argument types
	       * differently, we must use a different setter method
	       * for each argument type.
	       * FIXME ... support structures
	       * Unsupported types are quietly ignored ... is that right?
	       */
	      type = [sig getArgumentTypeAtIndex: 2];
	      switch (*type)
		{
		  case _C_CHR:
		  case _C_UCHR:
		    imp = [[GSKVOSetter class]
		      instanceMethodForSelector: @selector(setterChar:)];
		    break;
		  case _C_SHT:
		  case _C_USHT:
		    imp = [[GSKVOSetter class]
		      instanceMethodForSelector: @selector(setterShort:)];
		    break;
		  case _C_INT:
		  case _C_UINT:
		    imp = [[GSKVOSetter class]
		      instanceMethodForSelector: @selector(setterInt:)];
		    break;
		  case _C_LNG:
		  case _C_ULNG:
		    imp = [[GSKVOSetter class]
		      instanceMethodForSelector: @selector(setterLong:)];
		    break;
#ifdef  _C_LNG_LNG
		  case _C_LNG_LNG:
		  case _C_ULNG_LNG:
		    imp = [[GSKVOSetter class]
		      instanceMethodForSelector: @selector(setterLongLong:)];
		    break;
#endif
		  case _C_FLT:
		    imp = [[GSKVOSetter class]
		      instanceMethodForSelector: @selector(setterFloat:)];
		    break;
		  case _C_DBL:
		    imp = [[GSKVOSetter class]
		      instanceMethodForSelector: @selector(setterDouble:)];
		    break;
		  case _C_ID:
		  case _C_CLASS:
		  case _C_PTR:
		    imp = [[GSKVOSetter class]
		      instanceMethodForSelector: @selector(setter:)];
		    break;
		  default:
		    imp = 0;
		    break;
		}

	      if (imp != 0)
		{
		  GSAppendMethodToList(m, sel, [sig methodType], imp, YES);
		}
	    }
	  GSAddMethodList(p, m, YES);
	  GSFlushMethodCacheForClass(p);
	}

      NSMapInsert(classTable, (void*)c, (void*)p);
    }
  [kvoLock unlock];
  return p;
}

@implementation NSObject (NSKeyValueObserving)

/**
 * NOT IMPLEMENTED
 */
- (void) observeValueForKeyPath: (NSString*)aPath
		       ofObject: (id)anObject
			 change: (NSDictionary*)aChange
		        context: (void*)aContext
{
  return;
}

@end

@implementation NSObject (NSKeyValueObserverRegistration)

- (void) addObserver: (NSObject*)anObserver
	  forKeyPath: (NSString*)aPath
	     options: (NSKeyValueObservingOptions)options
	     context: (void*)aContext
{
  GSKVOInfo	*info;
  Class		c;

  setup();
  [kvoLock lock];

  /*
   * Get the existing observation information, creating it (and changing
   * the receiver to start key-value-observing by switching its class)
   * if necessary.
   */
  info = (GSKVOInfo*)[self observationInfo];
  if (info == nil)
    {
      c = classForInstance(self);
      info = [[GSKVOInfo alloc] initWithInstance: self];
      [self setObservationInfo: info];
      isa = c;
    }

  /*
   * Now add the observer.
   */
  [info addObserver: anObserver
	 forKeyPath: aPath
	    options: options
	    context: aContext];
  [kvoLock unlock];
}

- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath
{
  GSKVOInfo	*info;

  setup();
  [kvoLock lock];
  /*
   * Get the observation information and remove this observation.
   */
  info = (GSKVOInfo*)[self observationInfo];
  [info removeObserver: anObserver forKeyPath: aPath];
  if ([info isUnobserved] == YES)
    {
      /*
       * The instance is no longer bing observed ... so we can
       * turn off key-value-observing for it.
       */
      isa = [self class];
      AUTORELEASE(info);
      [self setObservationInfo: nil];
    }
  [kvoLock unlock];
}

@end

/**
 * NSArray objects are not observable, so the registration methods
 * raise an exception.
 */
@implementation NSArray (NSKeyValueObserverRegistration)

- (void) addObserver: (NSObject*)anObserver
	  forKeyPath: (NSString*)aPath
	     options: (NSKeyValueObservingOptions)options
	     context: (void*)aContext
{
  [NSException raise: NSGenericException
	      format: @"[%@-%@]: This class is not observable",
    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
}

- (void) addObserver: (NSObject*)anObserver
  toObjectsAtIndexes: (NSIndexSet*)indexes
	  forKeyPath: (NSString*)aPath
	     options: (NSKeyValueObservingOptions)options
	     context: (void*)aContext
{
  [self notImplemented: _cmd];
}

- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath
{
  [NSException raise: NSGenericException
	      format: @"[%@-%@]: This class is not observable",
    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
}

- (void) removeObserver: (NSObject*)anObserver
   fromObjectsAtIndexes: (NSIndexSet*)indexes
	     forKeyPath: (NSString*)aPath
{
  [self notImplemented: _cmd];
}

@end

/**
 * NSSet objects are not observable, so the registration methods
 * raise an exception.
 */
@implementation NSSet (NSKeyValueObserverRegistration)

- (void) addObserver: (NSObject*)anObserver
	  forKeyPath: (NSString*)aPath
	     options: (NSKeyValueObservingOptions)options
	     context: (void*)aContext
{
  [NSException raise: NSGenericException
	      format: @"[%@-%@]: This class is not observable",
    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
}

- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath
{
  [NSException raise: NSGenericException
	      format: @"[%@-%@]: This class is not observable",
    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
}

@end

@implementation NSObject (NSKeyValueObserverNotification)

- (void) didChangeValueForKey: (NSString*)aKey
{
  GSKVOInfo	*info = [self observationInfo];

  [info changeForKey: aKey];
}

- (void) didChange: (NSKeyValueChange)changeKind
   valuesAtIndexes: (NSIndexSet*)indexes
	    forKey: (NSString*)aKey
{
}

- (void) willChangeValueForKey: (NSString*)aKey
{
}

- (void) willChange: (NSKeyValueChange)changeKind
    valuesAtIndexes: (NSIndexSet*)indexes
	     forKey: (NSString*)aKey
{
}

- (void) didChangeValueForKey: (NSString*)aKey
	      withSetMutation: (NSKeyValueSetMutationKind)mutationKind
		 usingObjects: (NSSet*)objects
{
}

- (void) willChangeValueForKey: (NSString*)aKey
	       withSetMutation: (NSKeyValueSetMutationKind)mutationKind
		  usingObjects: (NSSet*)objects
{
}

@end

@implementation NSObject (NSKeyValueObservingCustomization)

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString*)aKey
{
  return YES;
}

+ (void) setKeys: (NSArray*)keys
triggerChangeNotificationsForDependentKey: (NSString*)dependentKey
{
  [self notImplemented: _cmd];
}

- (void*) observationInfo
{
  void	*info;

  setup();
  [kvoLock lock];
  info = NSMapGet(infoTable, (void*)self);
  AUTORELEASE(RETAIN((id)info));
  [kvoLock unlock];
  return info;
}

- (void) setObservationInfo: (void*)observationInfo
{
  setup();
  [kvoLock lock];
  if (observationInfo == 0)
    {
      NSMapRemove(infoTable, (void*)self);
    }
  else
    {
      NSMapInsert(infoTable, (void*)self, observationInfo);
    }
  [kvoLock unlock];
}

@end


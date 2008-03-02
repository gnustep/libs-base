/** Implementation of GNUSTEP key value observing
   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 2005

   This file is part of the GNUstep Base Library.

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

   $Date$ $Revision$
*/

#include "GNUstepBase/preface.h"
#import "Foundation/NSCharacterSet.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSHashTable.h"
#import "Foundation/NSKeyValueCoding.h"
#import "Foundation/NSKeyValueObserving.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSMethodSignature.h"
#import "Foundation/NSObject.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSString.h"
#import "Foundation/NSValue.h"
#import "GNUstepBase/GSObjCRuntime.h"
#import "GNUstepBase/Unicode.h"
#import "GNUstepBase/GSLock.h"

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

static NSRecursiveLock	*kvoLock = nil;
static NSMapTable	*classTable = 0;
static NSMapTable	*infoTable = 0;
static NSMapTable       *dependentKeyTable;
static Class		baseClass;

static inline void setup()
{
  if (kvoLock == nil)
    {
      kvoLock = [GSLazyRecursiveLock new];
      classTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
	NSNonOwnedPointerMapValueCallBacks, 128);
      infoTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
	NSNonOwnedPointerMapValueCallBacks, 1024);
      dependentKeyTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
          NSOwnedPointerMapValueCallBacks, 128);
      baseClass = NSClassFromString(@"GSKVOBase");
    }
}
/*
 * This is the template class whose methods are added to KVO classes to
 * override the originals and make the swizzled class look like the
 * original class.
 */
@interface	GSKVOBase : NSObject
@end

/*
 * This holds information about a subclass replacing a class which is
 * being observed.
 */
@interface	GSKVOReplacement : NSObject
{
  Class         original;       /* The original class */
  Class         replacement;    /* The replacement class */
  NSMutableSet  *keys;          /* The observed setter keys */
}
- (id) initWithClass: (Class)aClass;
- (void) overrideSetterFor: (NSString*)aKey;
- (Class) replacement;
@end

/*
 * This is a placeholder class which has the abstract setter method used
 * to replace all setter methods in the original.
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
  NSObject	        *instance;	// Not retained.
  NSLock	        *iLock;
  NSMapTable	        *paths;
  NSMutableDictionary   *changes;
}
- (NSMutableDictionary *) changeForKey: (NSString *)key;
- (void*) contextForObserver: (NSObject*)anObserver ofKeyPath: (NSString*)aPath;
- (id) initWithInstance: (NSObject*)i;
- (BOOL) isUnobserved;
- (void) notifyForKey: (NSString *)aKey ofChange: (NSDictionary *)change;
- (void) setChange: (NSMutableDictionary *)info forKey: (NSString *)key;

@end

@interface NSKeyValueObservationForwarder : NSObject
{
  id                                    target;
  NSKeyValueObservationForwarder        *child;
  void                                  *contextToForward;
  id                                    observedObjectForUpdate;
  NSString                              *keyForUpdate;
  id                                    observedObjectForForwarding;
  NSString                              *keyForForwarding;
  NSString                              *keyPathToForward;
}

+ (id) forwarderWithKeyPath: (NSString *)keyPath
                   ofObject: (id)object
                 withTarget: (id)aTarget
                    context: (void *)context;

- (id) initWithKeyPath: (NSString *)keyPath
              ofObject: (id)object
            withTarget: (id)aTarget
               context: (void *)context;

- (void) keyPathChanged: (id)objectToObserve;
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
  Class		c = [self class];
  void		(*imp)(id,SEL,id,id);

  imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];

  if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
      [self willChangeValueForKey: aKey];
      imp(self,_cmd,anObject,aKey);
      [self didChangeValueForKey: aKey];
    }
  else
    {
      imp(self,_cmd,anObject,aKey);
    }
}

- (void) takeStoredValue: (id)anObject forKey: (NSString*)aKey
{
  Class		c = [self class];
  void		(*imp)(id,SEL,id,id);

  imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];

  if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
      [self willChangeValueForKey: aKey];
      imp(self,_cmd,anObject,aKey);
      [self didChangeValueForKey: aKey];
    }
  else
    {
      imp(self,_cmd,anObject,aKey);
    }
}

- (void) takeValue: (id)anObject forKey: (NSString*)aKey
{
  Class		c = [self class];
  void		(*imp)(id,SEL,id,id);

  imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];

  if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
      [self willChangeValueForKey: aKey];
      imp(self,_cmd,anObject,aKey);
      [self didChangeValueForKey: aKey];
    }
  else
    {
      imp(self,_cmd,anObject,aKey);
    }
}

- (void) takeValue: (id)anObject forKeyPath: (NSString*)aKey
{
  Class		c = [self class];
  void		(*imp)(id,SEL,id,id);

  imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];

  if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
      [self willChangeValueForKey: aKey];
      imp(self,_cmd,anObject,aKey);
      [self didChangeValueForKey: aKey];
    }
  else
    {
      imp(self,_cmd,anObject,aKey);
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


static GSKVOReplacement *
replacementForClass(Class c)
{
  GSKVOReplacement *r;

  setup();

  [kvoLock lock];
  r = (GSKVOReplacement*)NSMapGet(classTable, (void*)c);
  if (r == nil)
    {
      r = [[GSKVOReplacement alloc] initWithClass: c];
      NSMapInsert(classTable, (void*)c, (void*)r);
    }
  [kvoLock unlock];
  return r;
}

@implementation	GSKVOReplacement
- (void) dealloc
{
  DESTROY(keys);
  [super dealloc];
}

- (id) initWithClass: (Class)aClass
{
  NSValue		*template;
  NSString		*superName;
  NSString		*name;

  if ([aClass instanceMethodForSelector: @selector(takeValue:forKey:)]
    != [NSObject instanceMethodForSelector: @selector(takeValue:forKey:)])
    {
      NSLog(@"WARNING The class '%@' (or one of its superclasses) overrides"
        @" the deprecated takeValue:forKey: method.  Using KVO to observe"
        @" this class may interfere with this method.  Please change the"
        @" class to override -setValue:forKey: instead.",
        NSStringFromClass(aClass));
    }
  if ([aClass instanceMethodForSelector: @selector(takeValue:forKeyPath:)]
    != [NSObject instanceMethodForSelector: @selector(takeValue:forKeyPath:)])
    {
      NSLog(@"WARNING The class '%@' (or one of its superclasses) overrides"
        @" the deprecated takeValue:forKeyPath: method.  Using KVO to observe"
        @" this class may interfere with this method.  Please change the"
        @" class to override -setValue:forKeyPath: instead.",
        NSStringFromClass(aClass));
    }
  original = aClass;

  /*
   * Create subclass of the original, and override some methods
   * with implementations from our abstract base class.
   */
  superName = NSStringFromClass(original);
  name = [@"GSKVO" stringByAppendingString: superName];
  template = GSObjCMakeClass(name, superName, nil);
  GSObjCAddClasses([NSArray arrayWithObject: template]);
  replacement = NSClassFromString(name);
  GSObjCAddClassBehavior(replacement, baseClass);

  /* Create the set of setter methods overridden.
   */
  keys = [NSMutableSet new];

  return self;
}

- (void) overrideSetterFor: (NSString*)aKey
{
  if ([keys member: aKey] == nil)
    {
      GSMethodList	m;
      NSMethodSignature	*sig;
      SEL		sel;
      IMP		imp;
      const char	*type;
      NSString          *suffix;
      NSString          *a[2];
      unsigned          i;
      BOOL              found = NO;
      NSString		*tmp;
      unichar u;

      m = GSAllocMethodList(2);

      suffix = [aKey substringFromIndex: 1];
      u = uni_toupper([aKey characterAtIndex: 0]);
      tmp = [[NSString alloc] initWithCharacters: &u length: 1];
      a[0] = [NSString stringWithFormat: @"set%@%@:", tmp, suffix];
      a[1] = [NSString stringWithFormat: @"_set%@%@:", tmp, suffix];
      for (i = 0; i < 2; i++)
        {
          /*
           * Replace original setter with our own version which does KVO
           * notifications.
           */
          sel = NSSelectorFromString(a[i]);
          if (sel == 0)
            {
              continue;
            }
          sig = [original instanceMethodSignatureForSelector: sel];
          if (sig == 0)
            {
              continue;
            }

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
              found = YES;
            }
        }
      if (found == YES)
        {
          GSAddMethodList(replacement, m, YES);
          GSFlushMethodCacheForClass(replacement);
          [keys addObject: aKey];
        }
      else
        {
          NSMapTable depKeys = NSMapGet(dependentKeyTable, original);

          if (depKeys)
            {
              NSMapEnumerator enumerator = NSEnumerateMapTable(depKeys);
              NSString *mainKey;
              NSHashTable dependents;

              while (NSNextMapEnumeratorPair(&enumerator, (void **)(&mainKey),
                &dependents))
                {
                  NSHashEnumerator dependentKeyEnum;
                  NSString *dependentKey;

                  if (!dependents) continue;
                  dependentKeyEnum = NSEnumerateHashTable(dependents);
                  while ((dependentKey
                    = NSNextHashEnumeratorItem(&dependentKeyEnum)))
                    {
                      if ([dependentKey isEqual: aKey])
                        {
                          [self overrideSetterFor: mainKey];
                          // Mark the key as used
                          [keys addObject: aKey];
                          found = YES;
                        }
                    }
                  NSEndHashTableEnumeration(&dependentKeyEnum);
               }
              NSEndMapTableEnumeration(&enumerator); 
            }

          if (!found)
            {
              NSLog(@"class %@ not KVC complient for %@", original, aKey);
              /*
              [NSException raise: NSInvalidArgumentException
                           format: @"class not KVC complient for %@", aKey];
              */
            }
        }
    }
}

- (Class) replacement
{
  return replacement;
}
@end

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

  imp = (void (*)(id,SEL,unsigned long long))
    [c instanceMethodForSelector: _cmd];

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
  NSMapTable    *observer;

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
  observer = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
      NSNonOwnedPointerMapValueCallBacks, 3);
  NSMapInsert(observer, (void *)@"context", aContext);
  NSMapInsert(observer, (void *)@"options", (void *)options);

  NSMapInsert(observers, (void*)anObserver, observer);
  [iLock unlock];
}

- (void) dealloc
{
  if (paths != 0) NSFreeMapTable(paths);
  RELEASE(iLock);
  RELEASE(changes);
  [super dealloc];
}

/*
 * FIXME: This method will provide the observer with both the old and new
 * values in the change dictionary, regardless of what was asked.
 */
- (void) notifyForKey: (NSString *)aKey ofChange: (NSDictionary *)change
{
  NSMapTable		*observers;

  [iLock lock];
  observers = (NSMapTable*)NSMapGet(paths, (void*)aKey);
  if (observers != 0)
    {
      NSMapEnumerator	enumerator;
      NSObject		*observer;
      NSMapTable        *info;
      void		*context;

      enumerator = NSEnumerateMapTable(observers);
      while (NSNextMapEnumeratorPair(&enumerator,
	(void **)(&observer), (void **)&info))
	{
	  if ([observer respondsToSelector:
	    @selector(observeValueForKeyPath:ofObject:change:context:)])
	    {
              context = NSMapGet(info, (void*)@"context");
	      [observer observeValueForKeyPath: aKey
				      ofObject: instance
					change: change
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
  changes = [[NSMutableDictionary alloc] init];
  return self;
}

- (void) setChange: (NSMutableDictionary *)info forKey: (NSString *)key
{
  [changes setValue: info forKey: key];
}

- (NSMutableDictionary *) changeForKey: (NSString *)key
{
  return [changes valueForKey: key];
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

/*
 * removes the observer and returns the context.
 */
- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath
{
  NSMapTable	*observers;
  NSMapTable    *observer;

  [iLock lock];
  observers = (NSMapTable*)NSMapGet(paths, (void*)aPath);
  if (observers != 0)
    {
      observer = NSMapGet(observers, (void*)anObserver);

      if (observer != 0)
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

- (void*) contextForObserver: (NSObject*)anObserver ofKeyPath: (NSString*)aPath
{
  NSMapTable	*observers;
  NSMapTable    *observer;
  void          *context = 0;

  [iLock lock];
  observers = (NSMapTable*)NSMapGet(paths, (void*)aPath);
  if (observers != 0)
    {
      observer = NSMapGet(observers, (void*)anObserver);

      if (observer != 0)
	{
          context = NSMapGet(observer, (void*)@"context");
	}
    }
  [iLock unlock];
  return context;
}
@end

@implementation NSKeyValueObservationForwarder

+ (id) forwarderWithKeyPath: (NSString *)keyPath
                   ofObject: (id)object
                 withTarget: (id)aTarget
                    context: (void *)context
{
  return [[self alloc] initWithKeyPath: keyPath
                              ofObject: object
                            withTarget: aTarget
                               context: context];
}

- (id) initWithKeyPath: (NSString *)keyPath
              ofObject: (id)object
            withTarget: (id)aTarget
               context: (void *)context
{
  NSString * remainingKeyPath;
  NSRange dot;

  target = aTarget;
  keyPathToForward = [keyPath copy];
  contextToForward = context;

  dot = [keyPath rangeOfString: @"."];
  if (dot.location == NSNotFound)
    {
      [NSException raise: NSInvalidArgumentException
        format: @"NSKeyValueObservationForwarder was not given a key path"];
    }
  keyForUpdate = [[keyPath substringToIndex: dot.location] copy];
  remainingKeyPath = [keyPath substringFromIndex: dot.location + 1];
  observedObjectForUpdate = object;
  [object addObserver: self
           forKeyPath: keyForUpdate
              options: NSKeyValueObservingOptionNew
                     | NSKeyValueObservingOptionOld
              context: target];
  dot = [remainingKeyPath rangeOfString: @"."];
  if (dot.location != NSNotFound)
    {
      child = [NSKeyValueObservationForwarder
        forwarderWithKeyPath: remainingKeyPath
                    ofObject: [object valueForKey: keyForUpdate]
                  withTarget: self
                     context: NULL];
      observedObjectForForwarding = nil;
    }
  else
    {
      keyForForwarding = [remainingKeyPath copy];
      observedObjectForForwarding = [object valueForKey: keyForUpdate];
      [observedObjectForForwarding addObserver: self
                                    forKeyPath: keyForForwarding
                                       options: NSKeyValueObservingOptionNew
                                              | NSKeyValueObservingOptionOld
                                       context: target];
      child = nil;
    }

  return self;
}

- (void) finalize
{
  if (child)
    {
      [child finalize];
    }
  if (observedObjectForUpdate)
    {
      [observedObjectForUpdate removeObserver: self forKeyPath: keyForUpdate];
    }
  if (observedObjectForForwarding)
    {
      [observedObjectForForwarding removeObserver: self forKeyPath: 
        keyForForwarding];
    }
  [self release];
}

- (void) dealloc
{
  [keyForUpdate release];
  [keyForForwarding release];
  [keyPathToForward release];

  [super dealloc];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)anObject
                         change: (NSDictionary *)change
                        context: (void *)context
{
  if (anObject == observedObjectForUpdate) 
    {
      [self keyPathChanged: nil];
    }
  else
    {
      [target observeValueForKeyPath: keyPathToForward
                            ofObject: observedObjectForUpdate
                              change: change
                             context: contextToForward];
    }
}

- (void) keyPathChanged: (id)objectToObserve
{
  if (objectToObserve != nil)
    {
      [observedObjectForUpdate removeObserver: self forKeyPath: keyForUpdate];
      observedObjectForUpdate = objectToObserve;
      [objectToObserve addObserver: self
                        forKeyPath: keyForUpdate
                           options: NSKeyValueObservingOptionNew
                                  | NSKeyValueObservingOptionOld
                           context: target];
    }
  if (child != nil)
    {
      [child keyPathChanged:
        [observedObjectForUpdate valueForKey: keyForUpdate]];
    }
  else
    {
      NSMutableDictionary *change;

      change = [NSMutableDictionary dictionaryWithObject: 
                                        [NSNumber numberWithInt: 1] 
                                    forKey:  NSKeyValueChangeKindKey];

      if (observedObjectForForwarding != nil)
        {
          id oldValue;

          oldValue
            = [observedObjectForForwarding valueForKey: keyForForwarding];
          [observedObjectForForwarding removeObserver: self forKeyPath: 
                                           keyForForwarding];
          if (oldValue)
            {
              [change setObject: oldValue forKey: NSKeyValueChangeOldKey];
            }
        }
      observedObjectForForwarding = [observedObjectForUpdate
        valueForKey:keyForUpdate];
      if (observedObjectForForwarding != nil)
        {
          id newValue;

          [observedObjectForForwarding addObserver: self
                                       forKeyPath: keyForForwarding
                                       options: NSKeyValueObservingOptionNew
                                       | NSKeyValueObservingOptionOld
                                       context: target];
          //prepare change notification
          newValue
            = [observedObjectForForwarding valueForKey: keyForForwarding];
          if (newValue)
            {
              [change setObject: newValue forKey: NSKeyValueChangeNewKey];
            }
        }
      [target observeValueForKeyPath: keyPathToForward
                            ofObject: observedObjectForUpdate
                              change: change
                             context: contextToForward];
    }
}

@end

@implementation NSObject (NSKeyValueObserving)

- (void) observeValueForKeyPath: (NSString*)aPath
		       ofObject: (id)anObject
			 change: (NSDictionary*)aChange
		        context: (void*)aContext
{
  [NSException raise: NSInvalidArgumentException
              format: @"-%@ cannot be sent to %@ ..."
              @" create an instance overriding this",
              NSStringFromSelector(_cmd), NSStringFromClass([self class])];
  return;
}

@end

@implementation NSObject (NSKeyValueObserverRegistration)

- (void) addObserver: (NSObject*)anObserver
	  forKeyPath: (NSString*)aPath
	     options: (NSKeyValueObservingOptions)options
	     context: (void*)aContext
{
  GSKVOInfo             *info;
  GSKVOReplacement      *r;
  NSKeyValueObservationForwarder *forwarder;
  NSRange               dot;

  setup();
  [kvoLock lock];

  // Use the original class
  r = replacementForClass([self class]);

  /*
   * Get the existing observation information, creating it (and changing
   * the receiver to start key-value-observing by switching its class)
   * if necessary.
   */
  info = (GSKVOInfo*)[self observationInfo];
  if (info == nil)
    {
      info = [[GSKVOInfo alloc] initWithInstance: self];
      [self setObservationInfo: info];
      isa = [r replacement];
    }

  /*
   * Now add the observer.
   */
  dot = [aPath rangeOfString:@"."];
  if (dot.location != NSNotFound)
    {
      forwarder = [NSKeyValueObservationForwarder
        forwarderWithKeyPath: aPath
                    ofObject: self
                  withTarget: anObserver
                     context: aContext];
      [info addObserver: anObserver
             forKeyPath: aPath
                options: options
                context: forwarder];
    }
  else
    {
      [r overrideSetterFor: aPath];
      [info addObserver: anObserver
             forKeyPath: aPath
                options: options
                context: aContext];
    }

  [kvoLock unlock];
}

- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath
{
  GSKVOInfo	*info;
  id forwarder;

  setup();
  [kvoLock lock];
  /*
   * Get the observation information and remove this observation.
   */
  info = (GSKVOInfo*)[self observationInfo];
  forwarder = [info contextForObserver: anObserver ofKeyPath: aPath];
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
  if ([aPath rangeOfString:@"."].location != NSNotFound)
    [forwarder finalize];
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

- (void) willChangeValueForDependentsOfKey: (NSString *)aKey
{
  NSMapTable keys = NSMapGet(dependentKeyTable, [self class]);

  if (keys)
    {
      NSHashTable       dependents = NSMapGet(keys, aKey);

      if (dependents != 0)
        {
          NSString              *dependentKey;
          NSHashEnumerator      dependentKeyEnum;

          dependentKeyEnum = NSEnumerateHashTable(dependents);
          while ((dependentKey = NSNextHashEnumeratorItem(&dependentKeyEnum)))
            {
              [self willChangeValueForKey: dependentKey];
            }
          NSEndHashTableEnumeration(&dependentKeyEnum);
        }
    }
}

- (void) didChangeValueForDependentsOfKey: (NSString *)aKey
{
  NSMapTable keys = NSMapGet(dependentKeyTable, [self class]);

  if (keys)
    {
      NSHashTable dependents = NSMapGet(keys, aKey);

      if (dependents != nil)
        {
          NSString              *dependentKey;
          NSHashEnumerator      dependentKeyEnum;

          dependentKeyEnum = NSEnumerateHashTable(dependents);
          while ((dependentKey = NSNextHashEnumeratorItem(&dependentKeyEnum)))
            {
              [self didChangeValueForKey: dependentKey];
            }
          NSEndHashTableEnumeration(&dependentKeyEnum);
        }
    }
}

- (void) willChangeValueForKey: (NSString*)aKey
{
  GSKVOInfo     *info;

  info = (GSKVOInfo *)[self observationInfo];
  if (info != nil)
    {
      id                        old;
      NSMutableDictionary       *change;

      change = [info changeForKey: aKey];
      if (change == nil)
        {
          change = [[NSMutableDictionary alloc] initWithCapacity: 1];
          [info setChange: change forKey: aKey];
          RELEASE(change);
        }
      old = [change objectForKey: NSKeyValueChangeNewKey];
      if (old == nil)
        {
          old = [self valueForKey: aKey];
          if (old == nil)
            {
              [change removeObjectForKey: NSKeyValueChangeOldKey];
            }
          else
            {
              [change setObject: old forKey: NSKeyValueChangeOldKey];
            }
        }
      else
        {
          [change setObject: old forKey: NSKeyValueChangeOldKey];
        }
      [change removeObjectForKey: NSKeyValueChangeNewKey];
      [change removeObjectForKey: NSKeyValueChangeKindKey];
    }
  [self willChangeValueForDependentsOfKey: aKey];
}

- (void) didChangeValueForKey: (NSString*)aKey
{
  GSKVOInfo	        *info;

  info = (GSKVOInfo *)[self observationInfo];
  if (info != nil)
    {
      NSMutableDictionary   *change;

      change = (NSMutableDictionary *)[info changeForKey: aKey];
      [change setValue: [self valueForKey: aKey]
                forKey: NSKeyValueChangeNewKey];
      [change setValue: [NSNumber numberWithInt: NSKeyValueChangeSetting]
                forKey: NSKeyValueChangeKindKey];
      [info notifyForKey: aKey ofChange: change];
    }
  [self didChangeValueForDependentsOfKey: aKey];
}

- (void) didChange: (NSKeyValueChange)changeKind
   valuesAtIndexes: (NSIndexSet*)indexes
	    forKey: (NSString*)aKey
{
  GSKVOInfo	        *info;

  info = [self observationInfo];
  if (info != nil)
    {
      NSMutableDictionary   *change;
      NSMutableArray        *array;

      change = (NSMutableDictionary *)[info changeForKey: aKey];
      array = [self valueForKey: aKey];

      [change setValue: [NSNumber numberWithInt: changeKind] forKey:
        NSKeyValueChangeKindKey];
      [change setValue: indexes forKey: NSKeyValueChangeIndexesKey];

      if (changeKind == NSKeyValueChangeInsertion
        || changeKind == NSKeyValueChangeReplacement)
        {
          [change setValue: [array objectsAtIndexes: indexes]
                    forKey: NSKeyValueChangeNewKey];
        }

      [info notifyForKey: aKey ofChange: change];
    }
  [self didChangeValueForDependentsOfKey: aKey];
}

- (void) willChange: (NSKeyValueChange)changeKind
    valuesAtIndexes: (NSIndexSet*)indexes
	     forKey: (NSString*)aKey
{
  GSKVOInfo	        *info;

  info = [self observationInfo];
    {
      NSMutableDictionary   *change;
      NSMutableArray        *array;

      change = [[NSMutableDictionary alloc] initWithCapacity: 1];
      array = [self valueForKey: aKey];

      if (changeKind == NSKeyValueChangeRemoval
        || changeKind == NSKeyValueChangeReplacement)
        {
          [change setValue: [array objectsAtIndexes: indexes]
                    forKey: NSKeyValueChangeOldKey];
        }

      [info setChange: change forKey: aKey];
      RELEASE(change);
    }
  [self willChangeValueForDependentsOfKey: aKey];
}

- (void) willChangeValueForKey: (NSString*)aKey
	       withSetMutation: (NSKeyValueSetMutationKind)mutationKind
		  usingObjects: (NSSet*)objects
{
  GSKVOInfo	*info;

  info = [self observationInfo];
  if (info != nil)
    {
      NSMutableDictionary       *change;
      NSMutableSet              *set;

      change = [[NSMutableDictionary alloc] initWithCapacity: 1];
      set = [self valueForKey: aKey];

      [change setValue: [set mutableCopy] forKey: @"oldSet"];
      [info setChange: change forKey: aKey];
      RELEASE(change);
    }
  [self willChangeValueForDependentsOfKey: aKey];
}

- (void) didChangeValueForKey: (NSString*)aKey
	      withSetMutation: (NSKeyValueSetMutationKind)mutationKind
		 usingObjects: (NSSet*)objects
{
  GSKVOInfo	        *info;

  info = (GSKVOInfo *)[self observationInfo];
  if (info != nil)
    {
      NSMutableDictionary   *change;
      NSMutableSet          *oldSet;
      NSMutableSet          *set;

      change = (NSMutableDictionary *)[info changeForKey: aKey];
      oldSet = [change valueForKey: @"oldSet"];
      set = [self valueForKey: aKey];
      [change setValue: nil forKey: @"oldSet"];
      if (mutationKind == NSKeyValueUnionSetMutation)
        {
          set = [set mutableCopy];
          [set minusSet: oldSet];
          [change setValue: [NSNumber numberWithInt: NSKeyValueChangeInsertion]
                    forKey: NSKeyValueChangeKindKey];
          [change setValue: set forKey: NSKeyValueChangeNewKey];
        }
      else if (mutationKind == NSKeyValueMinusSetMutation
        || mutationKind == NSKeyValueIntersectSetMutation)
        {
          [oldSet minusSet: set];
          [change setValue: [NSNumber numberWithInt: NSKeyValueChangeRemoval]
                    forKey: NSKeyValueChangeKindKey];
          [change setValue: oldSet forKey: NSKeyValueChangeOldKey];
        }
      else if (mutationKind == NSKeyValueSetSetMutation)
        {
          NSMutableSet      *old;
          NSMutableSet      *new;

          old = [oldSet mutableCopy];
          [old minusSet: set];
          new = [set mutableCopy];
          [new minusSet: oldSet];
          [change setValue:
            [NSNumber numberWithInt: NSKeyValueChangeReplacement]
                    forKey: NSKeyValueChangeKindKey];
          [change setValue: old forKey: NSKeyValueChangeOldKey];
          [change setValue: new forKey: NSKeyValueChangeNewKey];
        }
      [info notifyForKey: aKey ofChange: change];
    }
  [self didChangeValueForDependentsOfKey: aKey];
}

@end

@implementation NSObject (NSKeyValueObservingCustomization)

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString*)aKey
{
  return YES;
}

+ (void) setKeys: (NSArray*)triggerKeys
triggerChangeNotificationsForDependentKey: (NSString*)dependentKey
{
  NSMapTable    affectingKeys;
  NSEnumerator  *enumerator;
  NSString      *affectingKey;

  setup();
  affectingKeys = NSMapGet(dependentKeyTable, self);
  if (!affectingKeys)
    {
      affectingKeys = NSCreateMapTable(NSObjectMapKeyCallBacks,
        NSNonOwnedPointerMapValueCallBacks, 10);
      NSMapInsert(dependentKeyTable, self, affectingKeys);
    }
  enumerator = [triggerKeys objectEnumerator];
  while ((affectingKey = [enumerator nextObject]))
    {
      NSHashTable dependentKeys = NSMapGet(affectingKeys, affectingKey);
      if (!dependentKeys)
        {
          dependentKeys = NSCreateHashTable(NSObjectHashCallBacks, 10);
          NSMapInsert(affectingKeys, affectingKey, dependentKeys);
        }
      NSHashInsert(dependentKeys, dependentKey);
    }
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


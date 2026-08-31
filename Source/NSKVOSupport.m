/**
   NSKVOSupport.m

   Copyright (C) 2024 Free Software Foundation, Inc.

   Written by: Hugo Melder <hugo@algoriddim.com>
   Date: June 2024

   Based on WinObjC KVO tests by Microsoft Corporation.

   This file is part of GNUStep-base

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   If you are interested in a warranty or support for this source code,
   contact Scott Christley <scottc@net-community.com> for more information.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/
/**
  Copyright (c) Microsoft. All rights reserved.

  This code is licensed under the MIT License (MIT).

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
*/

/* This Key Value Observing Implementation is tied to libobjc2 */

#import "common.h"
#import "NSKVOInternal.h"

#import <Foundation/Foundation.h>

typedef void (*DispatchChangeFunction)(_NSKVOKeyObserver *, void *context);

static NSString *
_NSKVCSplitKeypath(NSString *keyPath, NSString **pRemainder)
{
  NSRange result = [keyPath rangeOfString:@"."];
  if (keyPath.length > 0 && result.location != NSNotFound)
    {
      *pRemainder = [keyPath substringFromIndex:result.location + 1];
      return [keyPath substringToIndex:result.location];
    }
  *pRemainder = nil;
  return keyPath;
}

#pragma region Key Observer
@implementation _NSKVOKeyObserver
/* GCC does not perform clang's default (automatic) property synthesis, so the
 * accessors are synthesized explicitly. */
@synthesize keypathObserver = _keypathObserver;
@synthesize restOfKeypathObserver = _restOfKeypathObserver;
@synthesize restOfKeypathRelay = _restOfKeypathRelay;
@synthesize dependentObservers = _dependentObservers;
@synthesize object = _object;
@synthesize key = _key;
@synthesize restOfKeypath = _restOfKeypath;
@synthesize affectedObservers = _affectedObservers;
@synthesize root = _root;

- (instancetype) initWithObject: (id)object
                keypathObserver: (_NSKVOKeypathObserver *)keypathObserver
                            key: (NSString *)key
                  restOfKeypath: (NSString *)restOfKeypath
              affectedObservers: (NSArray *)affectedObservers
{
  if (nil != (self = [super init]))
    {
      _object = object;
      _keypathObserver = RETAIN(keypathObserver);
      _key = [key copy];
      _restOfKeypath = [restOfKeypath copy];
      _affectedObservers = [affectedObservers copy];
    }
  return self;
}

- (void)dealloc
{
  [_keypathObserver release];
  [_key release];
  [_restOfKeypath release];
  [_dependentObservers release];
  [_restOfKeypathObserver release];
  [_restOfKeypathRelay release];
  [_affectedObservers release];
  [super dealloc];
}

- (BOOL)isRemoved
{
  return __atomic_load_n(&_isRemoved, __ATOMIC_SEQ_CST);
}

- (void)setIsRemoved: (BOOL)removed
{
  __atomic_store_n(&_isRemoved, removed, __ATOMIC_SEQ_CST);
}
@end
#pragma endregion

#pragma region Keypath Observer
/* The entire change dictionary for an observation registered with no options.
 * The same dictionary serves every such observation and every change, rather
 * than an equal one built per change.  It is immutable, so a write to it from
 * observeValueForKeyPath:ofObject:change:context: raises rather than altering
 * the next notification.
 */
static NSDictionary *_kvoSettingChange = nil;

@implementation _NSKVOKeypathObserver
+ (void) initialize
{
  if (self == [_NSKVOKeypathObserver class] && nil == _kvoSettingChange)
    {
      _kvoSettingChange = [[NSDictionary alloc]
        initWithObjects: (id[]){[NSNumber numberWithUnsignedInteger:
                                  NSKeyValueChangeSetting]}
                forKeys: (id[]){NSKeyValueChangeKindKey}
                  count: 1];
    }
}

@synthesize object = _object;
@synthesize observer = _observer;
@synthesize keypath = _keypath;
@synthesize options = _options;
@synthesize context = _context;
@synthesize pendingChange = _pendingChange;

- (instancetype) initWithObject: (id)object
                       observer: (id)observer
                        keyPath: (NSString *)keypath
                        options: (NSKeyValueObservingOptions)options
                        context: (void *)context
{
  if (nil != (self = [super init]))
    {
      _object = object;
      _observer = observer;
      _keypath = [keypath copy];
      _options = options;
      _context = context;
      GS_MUTEX_INIT_RECURSIVE(_changeLock);
    }
  return self;
}

- (void) dealloc
{
  [_keypath release];
  [_pendingChange release];
  GS_MUTEX_DESTROY(_changeLock);
  [super dealloc];
}

- (void) lockChange
{
  GS_MUTEX_LOCK(_changeLock);
}

- (void) unlockChange
{
  GS_MUTEX_UNLOCK(_changeLock);
}

- (void) beginDelivery
{
  __atomic_fetch_add(&_deliveryCount, 1, __ATOMIC_SEQ_CST);
}

- (void) endDelivery
{
  __atomic_fetch_sub(&_deliveryCount, 1, __ATOMIC_SEQ_CST);
}

- (BOOL) isDelivering
{
  return __atomic_load_n(&_deliveryCount, __ATOMIC_SEQ_CST) != 0;
}

- (BOOL) pushWillChange
{
  return __atomic_fetch_add(&_changeDepth, 1, __ATOMIC_SEQ_CST) == 0;
}

- (BOOL) popDidChange
{
  return __atomic_fetch_sub(&_changeDepth, 1, __ATOMIC_SEQ_CST) == 1;
}
@end
#pragma endregion

#pragma region Forwarding Relay
/* Stands between an object that registers observations on the objects it
 * holds and the observer of the whole key path.  The change is reported for
 * the key path being observed, on the object being observed, whichever of the
 * held objects it came from.
 */
@implementation _NSKVOForwardingRelay

- (instancetype) initWithObject: (id)object
                        keypath: (NSString *)keypath
                keypathObserver: (_NSKVOKeypathObserver *)keypathObserver
{
  if (nil != (self = [super init]))
    {
      _object = object;
      _keypath = [keypath copy];
      _keypathObserver = RETAIN(keypathObserver);

      [object addObserver: self
               forKeyPath: keypath
                  options: 0
                  context: NULL];
    }
  return self;
}

- (void) stop
{
  [_object removeObserver: self forKeyPath: _keypath];
  _object = nil;
}

- (void) dealloc
{
  [_keypath release];
  [_keypathObserver release];
  [super dealloc];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
  id                   observer = [_keypathObserver observer];
  NSString            *keypath = [_keypathObserver keypath];
  id                   rootObject = [_keypathObserver object];
  NSMutableDictionary *relayed;

  if (nil == observer)
    {
      return;
    }

  relayed = [NSMutableDictionary
    dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger:
                                   NSKeyValueChangeSetting],
                                 NSKeyValueChangeKindKey, nil];

  if (([_keypathObserver options] & NSKeyValueObservingOptionNew))
    {
      id newValue = [rootObject valueForKeyPath: keypath] ?: [NSNull null];

      [relayed setObject: newValue forKey: NSKeyValueChangeNewKey];
    }

  [observer observeValueForKeyPath: keypath
                          ofObject: rootObject
                            change: relayed
                           context: [_keypathObserver context]];
}

@end
#pragma endregion

#pragma region Object - level Observation Info
@implementation _NSKVOObservationInfo
- (instancetype) init
{
  if (nil != (self = [super init]))
    {
      _keyObserverMap = [[NSMutableDictionary alloc] initWithCapacity: 1];
      GS_MUTEX_INIT(_lock);
      GS_MUTEX_INIT_RECURSIVE(_changeLock);
    }
  return self;
}

- (void) lockChange
{
  GS_MUTEX_LOCK(_changeLock);
}

- (void) unlockChange
{
  GS_MUTEX_UNLOCK(_changeLock);
}

- (void) pushChangeSet: (NSArray *)set
{
  if (nil == _changeSets)
    {
      _changeSets = [[NSMutableArray alloc] initWithCapacity: 2];
    }
  /* A key with no observers still needs an entry, so that the didChange pops
   * what this willChange pushed. */
  [_changeSets addObject: (nil == set) ? (NSArray *)[NSArray array] : set];
}

/* Borrowed: the stack holds it until -popChangeSet. */
- (NSArray *) currentChangeSet
{
  NSUInteger	count = [_changeSets count];

  return (0 == count) ? nil : [_changeSets objectAtIndex: count - 1];
}

- (void) popChangeSet
{
  if ([_changeSets count] > 0)
    {
      [_changeSets removeLastObject];
    }
}

- (void) dealloc
{
  if (![self isEmpty])
    {
      // We only want to flag for root observers: anything we created internally
      // is fair game to be destroyed.
      for (NSString *key in [_keyObserverMap keyEnumerator])
        {
          for (_NSKVOKeyObserver *keyObserver in
               [_keyObserverMap objectForKey:key])
            {
              if (keyObserver.root)
                {
                  [NSException
                     raise:NSInvalidArgumentException
                    format:
                      @"Object %@ deallocated with observers still registered.",
                      keyObserver.object];
                }
            }
        }
    }
  [_keyObserverMap release];
  [_existingDependentKeys release];
  [_changeSets release];

  GS_MUTEX_DESTROY(_lock);
  GS_MUTEX_DESTROY(_changeLock);

  [super dealloc];
}

// While exploring the observer graph, for dependencies, we use this to 
// detect cycles to prevent infinite recursion. 
- (void) beginDependencyExpansionScope
{
  GS_MUTEX_LOCK(_lock);
  if (_dependencyDepth == 0)
    {
      _existingDependentKeys = [NSMutableSet new];
      _dependencyAncestorKeys = [NSMutableSet new];
    }
  ++_dependencyDepth;
  GS_MUTEX_UNLOCK(_lock);
}

/* Nodes (observable values) in the observer graph are uniquely identified
 * using a combination of the object pointer and the name of the value */
- (id) dependencyKeyForObject: (id)object key: (NSString *)key
{
  return [NSArray arrayWithObjects:
                   (object ?: [NSNull null]),
                   (key ?: @""),
                   nil];
}

- (void) pushObserverToCurrentAncestorStack: (_NSKVOKeyObserver *)keyObserver
{
  id ancestorKey = [self dependencyKeyForObject: keyObserver.object
                                            key: keyObserver.key];
  GS_MUTEX_LOCK(_lock);
  [_dependencyAncestorKeys addObject: ancestorKey];
  GS_MUTEX_UNLOCK(_lock);
}

- (void) popObserverFromCurrentAncestorStack: (_NSKVOKeyObserver *)keyObserver
{
  id ancestorKey = [self dependencyKeyForObject: keyObserver.object
                                            key: keyObserver.key];
  GS_MUTEX_LOCK(_lock);
  [_dependencyAncestorKeys removeObject: ancestorKey];
  GS_MUTEX_UNLOCK(_lock);
}

/// Mark keypath as visited in the current dependency-expansion scope.
- (BOOL) checkDependencyForCycle: (NSString *)keypath
                             forNode: (_NSKVOKeyObserver *)keyObserver
{
  NSString *dependentKey;
  NSString *unusedRemainder;
  id visitToken;

  dependentKey = _NSKVCSplitKeypath(keypath, &unusedRemainder);
  visitToken = [self dependencyKeyForObject: keyObserver.object
                                        key: dependentKey];
  GS_MUTEX_LOCK(_lock);
  if ([_existingDependentKeys containsObject:visitToken])
    {
      BOOL isCycle = [_dependencyAncestorKeys containsObject: visitToken];
      GS_MUTEX_UNLOCK(_lock);
      // If it's on the current ancestor stack, treat as cycle and dedup.
      // If it's already visited but not on stack, allow expansion to continue.
      return !isCycle;
    }
  [_existingDependentKeys addObject:visitToken];
  GS_MUTEX_UNLOCK(_lock);
  return YES;
}

- (void) endDependencyExpansionScope
{
  GS_MUTEX_LOCK(_lock);
  --_dependencyDepth;
  if (_dependencyDepth == 0)
    {
      [_existingDependentKeys release];
      _existingDependentKeys = nil;
      [_dependencyAncestorKeys release];
      _dependencyAncestorKeys = nil;
    }
  GS_MUTEX_UNLOCK(_lock);
}

/* The per-key observer arrays are stored copy-on-write: they are never
 * mutated in place once stored, so -observersForKey: can hand out a snapshot
 * without copying, and a snapshot being enumerated stays valid even if an
 * observer callback adds or removes observers. */
- (void) addObserver: (_NSKVOKeyObserver *)observer
{
  NSString	*key = observer.key;
  NSArray	*observersForKey;

  GS_MUTEX_LOCK(_lock);
  observersForKey = [_keyObserverMap objectForKey:key];
  if (observersForKey)
    {
      observersForKey = [observersForKey arrayByAddingObject:observer];
    }
  else
    {
      observersForKey = [NSArray arrayWithObject:observer];
    }
  [_keyObserverMap setObject:observersForKey forKey:key];
  GS_MUTEX_UNLOCK(_lock);
}

- (void) removeObserver: (_NSKVOKeyObserver *)observer
{
  NSString	*key;
  NSArray	*observersForKey;

  GS_MUTEX_LOCK(_lock);
  key = observer.key;
  observersForKey = [_keyObserverMap objectForKey:key];
  [observer setIsRemoved: YES];
  if (observersForKey != nil)
    {
      NSMutableArray *updated = [[observersForKey mutableCopy] autorelease];

      [updated removeObject:observer];
      if ([updated count] == 0)
        {
          [_keyObserverMap removeObjectForKey:key];
        }
      else
        {
          [_keyObserverMap setObject:updated forKey:key];
        }
    }
  GS_MUTEX_UNLOCK(_lock);
}

- (NSArray *) observersForKey: (NSString *)key
{
  NSArray	*result;

  GS_MUTEX_LOCK(_lock);
  result = [[[_keyObserverMap objectForKey:key] retain] autorelease];
  GS_MUTEX_UNLOCK(_lock);
  return result;
}

- (BOOL) isEmpty
{
  BOOL result;

  GS_MUTEX_LOCK(_lock);
  result = (_keyObserverMap.count == 0);
  GS_MUTEX_UNLOCK(_lock);
  return result;
}
@end

static _NSKVOObservationInfo *
_createObservationInfoForObject(id object)
{
  _NSKVOObservationInfo *observationInfo = [_NSKVOObservationInfo new];
  [object setObservationInfo:observationInfo];
  [observationInfo release];
  return observationInfo;
}
#pragma endregion

#pragma region Observer / Key Registration
static _NSKVOKeyObserver *
_addKeypathObserver(id object, NSString *keypath,
                    _NSKVOKeypathObserver *keyPathObserver,
                    NSArray               *affectedObservers);
static void
_removeKeyObserver(_NSKVOKeyObserver *keyObserver);

/* An object may register observations on the objects it holds, by way of its
 * own -addObserver:forKeyPath:options:context:.  That implementation has to be
 * used or nothing it holds is ever observed.  A plain collection, which
 * refuses the registration, and a proxy, which forwards the method and so
 * would look like such an object, are both left to the ordinary path.
 */
static BOOL
_registersObservationsItself(id object)
{
  SEL   selector = @selector(addObserver:forKeyPath:options:context:);
  Class class;
  Class root;
  IMP   implementation;

  if (nil == object)
    {
      return NO;
    }

  root = class = object_getClass(object);
  while (class_getSuperclass(root) != Nil)
    {
      root = class_getSuperclass(root);
    }
  if (root != [NSObject class])
    {
      return NO;
    }

  implementation = class_getMethodImplementation(class, selector);

  return implementation
      != class_getMethodImplementation([NSObject class], selector)
    && implementation
      != class_getMethodImplementation([NSArray class], selector)
    && implementation
      != class_getMethodImplementation([NSSet class], selector);
}

/* Whether the value refuses observer registration, which is what a plain
 * collection does.  A key path cannot continue through one: the collection
 * reports no change for a property of the objects it holds.
 */
static BOOL
_refusesObservation(id object)
{
  SEL   selector = @selector(addObserver:forKeyPath:options:context:);
  IMP   implementation;

  if (nil == object)
    {
      return NO;
    }
  implementation
    = class_getMethodImplementation(object_getClass(object), selector);

  return implementation
      == class_getMethodImplementation([NSArray class], selector)
    || implementation
      == class_getMethodImplementation([NSSet class], selector);
}

/* Observe the rest of a key path on the value of its first key. */
static void
_attachRestOfKeypath(_NSKVOKeyObserver *keyObserver)
{
  id value = [keyObserver.object valueForKey: keyObserver.key];

  /* An operator reads through the collection and reports the result for the
   * whole key path, so it is registered as any other key is.  Any other key
   * names a property of the objects the collection holds, and the collection
   * raises for it, as it does when the same key path is registered on it
   * directly.
   */
  if (_refusesObservation(value)
    && NO == [keyObserver.restOfKeypath hasPrefix: @"@"])
    {
      _NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;

      [value addObserver: keypathObserver.observer
              forKeyPath: keyObserver.restOfKeypath
                 options: keypathObserver.options
                 context: keypathObserver.context];
      return;
    }

  if (_registersObservationsItself(value))
    {
      _NSKVOForwardingRelay *relay;

      relay = [[_NSKVOForwardingRelay alloc]
                initWithObject: value
                       keypath: keyObserver.restOfKeypath
               keypathObserver: keyObserver.keypathObserver];
      keyObserver.restOfKeypathRelay = relay;
      [relay release];
    }
  else
    {
      keyObserver.restOfKeypathObserver
        = _addKeypathObserver(value, keyObserver.restOfKeypath,
                              keyObserver.keypathObserver,
                              keyObserver.affectedObservers);
    }
}

static void
_detachRestOfKeypath(_NSKVOKeyObserver *keyObserver)
{
  if (keyObserver.restOfKeypathRelay)
    {
      [keyObserver.restOfKeypathRelay stop];
      keyObserver.restOfKeypathRelay = nil;
    }
  if (keyObserver.restOfKeypathObserver)
    {
      _removeKeyObserver(keyObserver.restOfKeypathObserver);
      keyObserver.restOfKeypathObserver = nil;
    }
}

// Add all observers with declared dependencies on this one:
// * All keypaths that could trigger a change (keypaths for values affecting
// us).
// * The head of the remaining keypath.
static void
_addNestedObserversAndOptionallyDependents(_NSKVOKeyObserver *keyObserver,
                                           BOOL               dependents)
{
  id                     object;
  NSString              *key;
  _NSKVOKeypathObserver *keypathObserver;

  /* Fast path: a simple (non-keypath) observer with no dependents to
   * reconstruct and no affected observers has no nested work here. */
  if (!dependents && keyObserver.restOfKeypath == nil
      && keyObserver.affectedObservers == nil)
    {
      return;
    }

  object = keyObserver.object;
  key = keyObserver.key;
  keypathObserver = keyObserver.keypathObserver;

  // Aggregate all keys whose values will affect us.
  if (dependents)
    {
      _NSKVOObservationInfo *observationInfo
        = (_NSKVOObservationInfo *) [object observationInfo]
            ?: _createObservationInfoForObject(object);
      // Make sure to retrieve the underlying class of the observee.
      // This is just [object class] for an NSObject derived class.
      // When observing an object through a proxy, we instead use KVC
      // to optain the underlying class.
      Class cls = [object _underlyingClass];
      NSSet *valueInfluencingKeys = [cls keyPathsForValuesAffectingValueForKey: key];
      if (valueInfluencingKeys.count > 0)
        {
          NSArray 		*affectedKeyObservers;
          NSMutableArray 	*dependentObservers;

          affectedKeyObservers = keyObserver.affectedObservers;

          /* affectedKeyObservers is the list of observers that must be notified
           * of changes. If we have descendants, we have to add ourselves to the
           * growing list of affected keys. If not, we must pass it along
           * unmodified. (This is a minor optimization: we don't need to signal
           * for our own reconstruction if we have no subpath observers.)
           */
          if (keyObserver.restOfKeypath)
          {
            if (affectedKeyObservers)
              {
                affectedKeyObservers =
                  [affectedKeyObservers arrayByAddingObject:keyObserver];
              }
            else
              {
                affectedKeyObservers = [NSArray arrayWithObject:keyObserver];
              }
          }

          [observationInfo beginDependencyExpansionScope];
          [observationInfo pushObserverToCurrentAncestorStack: keyObserver];
          /* Don't allow our own key to be recreated. */
          [observationInfo checkDependencyForCycle:keyObserver.key
                                               forNode:keyObserver];

          /* The observers, which affect us */
          dependentObservers =
            [NSMutableArray arrayWithCapacity:[valueInfluencingKeys count]];
          for (NSString *dependentKeypath in valueInfluencingKeys)
            {
              if ([observationInfo checkDependencyForCycle:dependentKeypath
                                                       forNode:keyObserver])
                {
                  _NSKVOKeyObserver *dependentObserver
                    = _addKeypathObserver(object, dependentKeypath,
                                          keypathObserver,
                                          affectedKeyObservers);
                  if (dependentObserver)
                    {
                      [dependentObservers addObject:dependentObserver];
                    }
                }
            }
          keyObserver.dependentObservers = dependentObservers;

          [observationInfo popObserverFromCurrentAncestorStack: keyObserver];
          [observationInfo endDependencyExpansionScope];
        }
    }
  else
    {
      // Our dependents still exist, but their leaves have been pruned. Give
      // them the same treatment as us: recreate their leaves.
      for (_NSKVOKeyObserver *dependentKeyObserver in keyObserver
             .dependentObservers)
        {
          _addNestedObserversAndOptionallyDependents(dependentKeyObserver,
                                                     false);
        }
    }

  // If restOfKeypath is non-nil, we have to chain on further observers.
  if (keyObserver.restOfKeypath && !keyObserver.restOfKeypathObserver
      && !keyObserver.restOfKeypathRelay)
    {
      _attachRestOfKeypath(keyObserver);
    }

  // Back-propagation of changes.
  // This is where a value-affecting key signals to its dependent that it should
  // be reconstructed.
  for (_NSKVOKeyObserver *affectedObserver in keyObserver.affectedObservers)
    {
      if (!affectedObserver.restOfKeypathObserver
          && !affectedObserver.restOfKeypathRelay)
        {
          _attachRestOfKeypath(affectedObserver);
        }
    }
}

static void
_addKeyObserver(_NSKVOKeyObserver *keyObserver)
{
  _NSKVOObservationInfo	*observationInfo;
  id 			object = keyObserver.object;

  _NSKVOEnsureKeyWillNotify(object, keyObserver.key);
  observationInfo
    = (_NSKVOObservationInfo *) [object observationInfo]
      ?: _createObservationInfoForObject(object);
  [observationInfo addObserver:keyObserver];
}

static _NSKVOKeyObserver *
_addKeypathObserver(id object, NSString *keypath,
  _NSKVOKeypathObserver *keyPathObserver, NSArray *affectedObservers)
{
  _NSKVOKeyObserver	*keyObserver;
  NSString 		*key;
  NSString 		*restOfKeypath;

  if (!object)
    {
      return nil;
    }
  key = _NSKVCSplitKeypath(keypath, &restOfKeypath);

  keyObserver =
    [[[_NSKVOKeyObserver alloc] initWithObject:object
                               keypathObserver:keyPathObserver
                                           key:key
                                 restOfKeypath:restOfKeypath
                             affectedObservers:affectedObservers] autorelease];

  if (object)
    {
      _addNestedObserversAndOptionallyDependents(keyObserver, true);
      _addKeyObserver(keyObserver);
    } else {
    }

  return keyObserver;
}
#pragma endregion

#pragma region Observer / Key Deregistration
static void
_removeNestedObserversAndOptionallyDependents(_NSKVOKeyObserver *keyObserver,
  BOOL dependents)
{
  /* Fast path: a simple (non-keypath) observer with no dependents and no
   * affected observers has no nested work here. */
  if (!dependents && keyObserver.restOfKeypathObserver == nil
      && keyObserver.restOfKeypathRelay == nil
      && keyObserver.dependentObservers == nil
      && keyObserver.affectedObservers == nil)
    {
      return;
    }

  // Destroy the subpath observer recursively.
  _detachRestOfKeypath(keyObserver);

  if (dependents)
    {
      // Destroy each observer whose value affects ours, recursively.
      for (_NSKVOKeyObserver *dependentKeyObserver in keyObserver
             .dependentObservers)
        {
          _removeKeyObserver(dependentKeyObserver);
        }

      keyObserver.dependentObservers = nil;
    }
  else
    {
      // Our dependents must be kept alive but pruned.
      for (_NSKVOKeyObserver *dependentKeyObserver in keyObserver
             .dependentObservers)
        {
          _removeNestedObserversAndOptionallyDependents(dependentKeyObserver,
                                                        false);
        }
    }

  if (keyObserver.affectedObservers)
    {
      // Begin to reconstruct each observer that depends on our key's value
      // (triggers in _addDependentAndNestedObservers).
      for (_NSKVOKeyObserver *affectedObserver in keyObserver.affectedObservers)
        {
          _detachRestOfKeypath(affectedObserver);
        }
    }
}

static void
_removeKeyObserver(_NSKVOKeyObserver *keyObserver)
{
  _NSKVOObservationInfo *observationInfo;

  if (!keyObserver)
    {
      return;
    }

  observationInfo
    = (_NSKVOObservationInfo *) [keyObserver.object observationInfo];

  [keyObserver retain];

  _removeNestedObserversAndOptionallyDependents(keyObserver, true);

  // These are removed elsewhere; we're probably being cleared as a result of
  // their deletion anyway.
  keyObserver.affectedObservers = nil;

  [observationInfo removeObserver:keyObserver];

  [keyObserver release];
}

static void
_removeKeypathObserver(id object, NSString *keypath, id observer, void *context)
{
  NSString 		*key;
  NSString 		*restOfKeypath;
  _NSKVOObservationInfo	*observationInfo;

  key = _NSKVCSplitKeypath(keypath, &restOfKeypath);

  observationInfo = (_NSKVOObservationInfo *) [object observationInfo];
  for (_NSKVOKeyObserver *keyObserver in [observationInfo observersForKey:key])
    {
      _NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;

      if (keypathObserver.observer == observer
        && keypathObserver.object == object
	&& [keypathObserver.keypath isEqual:keypath]
        && (!context || keypathObserver.context == context))
        {
          _removeKeyObserver(keyObserver);
          return;
        }
    }

  [NSException raise: NSInvalidArgumentException
              format: @"Cannot remove observer %@ for keypath \"%@\" from %@"
    @" as it is not a registered observer.",
    observer, keypath, object];
}
#pragma endregion

#pragma region KVO Core Implementation - NSObject category

static const char *const KVO_MAP = "_NSKVOMap";

@implementation
NSObject (NSKeyValueObserving)

+ (void) setKeys: (NSArray *) triggerKeys 
triggerChangeNotificationsForDependentKey: (NSString *) dependentKey
{
  NSMutableDictionary *affectingKeys;
  NSSet *triggerKeySet;

  affectingKeys = objc_getAssociatedObject(self, KVO_MAP);
  if (nil == affectingKeys)
    {
      affectingKeys = [NSMutableDictionary dictionaryWithCapacity: 10];
      objc_setAssociatedObject(self, KVO_MAP, affectingKeys,
                               OBJC_ASSOCIATION_RETAIN);
    }

  triggerKeySet = [NSSet setWithArray: triggerKeys];
  [affectingKeys setValue: triggerKeySet forKey: dependentKey];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
  [NSException raise: NSInternalInconsistencyException
              format: @"A key-value observation notification fired, but nobody "
    @"responded to it: object %@, keypath %@, change %@.",
    object, keyPath, change];
}

static void *s_kvoObservationInfoAssociationKey; // has no value; pointer used
                                                 // as an association key.

- (void *) observationInfo
{
  return (void *)
    objc_getAssociatedObject(self, &s_kvoObservationInfoAssociationKey);
}

- (void) setObservationInfo: (void *)observationInfo
{
  objc_setAssociatedObject(self, &s_kvoObservationInfoAssociationKey,
    (id) observationInfo,
    OBJC_ASSOCIATION_RETAIN);
}

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString *)key
{
  if ([key length] > 0)
    {
      static const char *const	sc_prefix = "automaticallyNotifiesObserversOf";
      static const size_t     	sc_prefixLength = 32; // strlen(sc_prefix)
      const char               	*rawKey = [key UTF8String];
      size_t                   	keyLength = strlen(rawKey);
      size_t                   	bufferSize = sc_prefixLength + keyLength + 1;
      char                    	*selectorName = (char *) malloc(bufferSize);
      SEL 			sel;

      memcpy(selectorName, sc_prefix, sc_prefixLength);
      selectorName[sc_prefixLength] = toupper(rawKey[0]);
      memcpy(&selectorName[sc_prefixLength + 1], &rawKey[1],
             keyLength); // copy keyLength characters to include terminating
                         // NULL from rawKey
      sel = sel_registerName(selectorName);
      free(selectorName);
      if ([self respondsToSelector:sel])
        {
          IMP imp = [self methodForSelector:sel];
          return ((BOOL(*)(id, SEL)) imp)(self, sel);
        }
    }
  return YES;
}

+ (NSSet *) keyPathsForValuesAffectingValueForKey: (NSString *)key
{
  static gs_mutex_t	lock = GS_MUTEX_INIT_STATIC;
  static NSSet		*emptySet = nil;
  NSUInteger 		keyLength;
  NSDictionary *affectingKeys;

  if (nil == emptySet)
    {
      GS_MUTEX_LOCK(lock);
      if (nil == emptySet)
        {
          emptySet = [NSSet new];	// Exists forever.
        }
      GS_MUTEX_UNLOCK(lock);
    }

  // This function can be a KVO bottleneck, so it will prefer to use c string
  // manipulation when safe
  keyLength = [key length];
  if (keyLength > 0)
    {
      static const char *const	sc_prefix = "keyPathsForValuesAffecting";
      static const size_t      	sc_prefixLength = 26; // strlen(sc_prefix)
      static const size_t      	sc_bufferSize = 128;
      const char 		*rawKey;
      size_t      		rawKeyLength;
      SEL         		sel;

      rawKey = [key UTF8String];
      rawKeyLength = strlen(rawKey);

      /* max length of a key that can guaranteed fit in the char buffer,
       * even if UTF16->UTF8 conversion causes length to double, or a null
       * terminator is needed
       */
      if (keyLength <= (sc_bufferSize - sc_prefixLength) / 2 - 1)
        {
          // fast path using c string manipulation, will cover most cases, as
          // most keyPaths are short
          char selectorName[sc_bufferSize];

	  strncpy(selectorName, "keyPathsForValuesAffecting", sc_prefixLength);

          selectorName[sc_prefixLength] = toupper(rawKey[0]);
          // Copy the rest of the key, including the null terminator
          memcpy(&selectorName[sc_prefixLength + 1], &rawKey[1], rawKeyLength);
          sel = sel_registerName(selectorName);
        }
      else // Guaranteed path for long keyPaths
        {
          size_t keyLength;
          size_t bufferSize;
          char  *selectorName;

          keyLength = strlen(rawKey);
          bufferSize = sc_prefixLength + keyLength + 1;
          selectorName = (char *) malloc(bufferSize);
          memcpy(selectorName, sc_prefix, sc_prefixLength);

          selectorName[sc_prefixLength] = toupper(rawKey[0]);
          // Copy the rest of the key, including the null terminator
          memcpy(&selectorName[sc_prefixLength + 1], &rawKey[1], keyLength);

          sel = sel_registerName(selectorName);
          free(selectorName);
        }

      if ([self respondsToSelector:sel])
        {
          return [self performSelector:sel];
        }

      /* We compute an NSSet from information provided by previous
       * invocations of the now-deprecated
       * setKeys:triggerChangeNotificationsForDependentKey:
       * if the original imp returns an empty set.
       * This aligns with Apple's backwards compatibility.
       */
      affectingKeys = (NSDictionary *)objc_getAssociatedObject(self, KVO_MAP);
      if (unlikely(nil != affectingKeys))
        {
          NSSet *set = [affectingKeys objectForKey:key];

          if (set != nil)
            {
	      return set;
            }
        }
    }
  return emptySet;
}

- (void) addObserver: (NSObject*)observer
          forKeyPath: (NSString*)keyPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)context
{
  _NSKVOKeypathObserver *keypathObserver =
    [[[_NSKVOKeypathObserver alloc] initWithObject: self
                                          observer: observer
                                           keyPath: keyPath
                                           options: options
                                           context: context] autorelease];
  _NSKVOKeyObserver *rootObserver
    = _addKeypathObserver(self, keyPath, keypathObserver, nil);
  rootObserver.root = true;

  if ((options & NSKeyValueObservingOptionInitial))
    {
      NSMutableDictionary *change = [NSMutableDictionary
        dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger: NSKeyValueChangeSetting],
                                     NSKeyValueChangeKindKey, nil];

      if ((options & NSKeyValueObservingOptionNew))
        {
          id newValue = [self valueForKeyPath:keyPath] ?: [NSNull null];
          [change setObject:newValue forKey:NSKeyValueChangeNewKey];
        }

      [observer observeValueForKeyPath:keyPath
                              ofObject:self
                                change:change
                               context:context];
    }
}

- (void) removeObserver: (NSObject*)observer
             forKeyPath: (NSString*)keyPath
                context: (void*)context
{
  _NSKVOObservationInfo *observationInfo;

  _removeKeypathObserver(self, keyPath, observer, context);
  observationInfo = (_NSKVOObservationInfo *) [self observationInfo];
  if ([observationInfo isEmpty])
    {
      // TODO: was nullptr prior
      [self setObservationInfo:nil];
    }
}

- (void) removeObserver: (NSObject*)observer forKeyPath: (NSString*)keyPath
{
  [self removeObserver:observer forKeyPath:keyPath context:NULL];
}

// Reference platform does not provide the Set Mutation Kind in the changes
// dictionary, just shows which elements were inserted/removed/replaced
static inline NSKeyValueChange
_changeFromSetMutationKind(NSKeyValueSetMutationKind kind)
{
  switch (kind)
    {
    case NSKeyValueUnionSetMutation:
      return NSKeyValueChangeInsertion;
    case NSKeyValueMinusSetMutation:
    case NSKeyValueIntersectSetMutation:
      return NSKeyValueChangeRemoval;
    default:
      return NSKeyValueChangeReplacement;
    }
}

static inline id
_valueForPendingChangeAtIndexes(id notifyingObject, NSString *key,
                                NSString *keypath, id rootObject,
                                _NSKVOKeyObserver *keyObserver,
                                NSDictionary      *pendingChange)
{
  id          value = nil;
  NSIndexSet *indexes = [pendingChange objectForKey: NSKeyValueChangeIndexesKey];
  if (indexes)
    {
      NSArray  *collection = [notifyingObject valueForKey:key];
      NSString *restOfKeypath = keyObserver.restOfKeypath;
      value = restOfKeypath.length > 0
                ? [collection valueForKeyPath:restOfKeypath]
                : collection;
      if ([value respondsToSelector:@selector(objectsAtIndexes:)])
        {
          value = [value objectsAtIndexes:indexes];
        }
    }
  else
    {
      value = [rootObject valueForKeyPath:keypath];
    }

  return value ?: [NSNull null];
}

// void TFunc(_NSKVOKeyObserver* keyObserver);
inline static void
_dispatchWillChange(_NSKVOObservationInfo *observationInfo,
                    id notifyingObject, NSString *key,
                    DispatchChangeFunction fn, void *changeContext)
{
  NSArray *observers;

  if (nil == observationInfo)
    {
      return;
    }
  [observationInfo lockChange];
  observers = [observationInfo observersForKey:key];
  /* Held until the matching didChange, which locks and unlocks this same
   * array.  Registering or removing an observer replaces the array rather
   * than changing it, so what is locked here cannot be added to or taken
   * away from before it is unlocked. */
  [observationInfo pushChangeSet: observers];
  for (_NSKVOKeyObserver *keyObserver in observers)
    {
      _NSKVOKeypathObserver *keypathObserver;

      /* Every observer in the array is locked, including one already marked
       * removed, so that the didChange has the same set to unlock.  Whether
       * there is work to do is a separate question, below. */
      keypathObserver = keyObserver.keypathObserver;
      [keypathObserver lockChange];
      if ([keypathObserver pushWillChange] && !keyObserver.isRemoved)
        {
          NSKeyValueObservingOptions options;

          // Call into the change function, which does the actual set-up for
          // pendingChanges
          fn(keyObserver, changeContext);

          options = keypathObserver.options;
          if (options & NSKeyValueObservingOptionPrior)
            {
              NSMutableDictionary *change = keypathObserver.pendingChange;

              [change setObject:[NSNumber numberWithBool: YES]
                         forKey:NSKeyValueChangeNotificationIsPriorKey];
              [keypathObserver.observer
                observeValueForKeyPath:keypathObserver.keypath
                              ofObject:keypathObserver.object
                                change:change
                               context:keypathObserver.context];
              [change
                removeObjectForKey:NSKeyValueChangeNotificationIsPriorKey];
            }
        }

      // This must happen regardless of whether we are currently notifying.
      if (!keyObserver.isRemoved)
        {
          _removeNestedObserversAndOptionallyDependents(keyObserver, false);
        }
    }
  /* The matching -unlockChange calls are in _dispatchDidChange. */
}

/* One observer call, held until every lock has been dropped. */
typedef struct {
  _NSKVOKeypathObserver *keypathObserver;
  NSMutableDictionary   *change;
} GSKVOPendingNotification;

static void
_dispatchDidChange(_NSKVOObservationInfo *observationInfo,
                   id notifyingObject, NSString *key,
                   DispatchChangeFunction fn, void *changeContext)
{
  GSKVOPendingNotification   held[8];
  GSKVOPendingNotification  *pending = held;
  NSUInteger                 count = 0;
  NSArray                   *observers;
  NSUInteger                 index;

  if (nil == observationInfo)
    {
      return;
    }
  /* Exactly what _dispatchWillChange locked, so that an observer registered
   * or removed while the change was in progress cannot leave a key path
   * observer locked, or unlock one that was never locked. */
  observers = [observationInfo currentChangeSet];
  index = [observers count];
  if (index > sizeof(held) / sizeof(held[0]))
    {
      pending = malloc(index * sizeof(GSKVOPendingNotification));
    }
  /* Notify in reverse order (a plain index loop avoids allocating an
   * NSReverseEnumerator on every change). */
  while (index-- > 0)
    {
      _NSKVOKeyObserver     *keyObserver = [observers objectAtIndex: index];
      _NSKVOKeypathObserver *keypathObserver;
      BOOL                   removed = keyObserver.isRemoved;

      if (!removed)
        {
          // This must happen regardless of whether we are currently notifying.
          _addNestedObserversAndOptionallyDependents(keyObserver, false);
        }

      /* The change depth is popped even for an observer removed during the
       * change, because the willChange pushed it. */
      keypathObserver = keyObserver.keypathObserver;
      if ([keypathObserver popDidChange] && !removed)
        {
          // Call into the change function, which does set-up for finalizing
          // the changes dictionary
          fn(keyObserver, changeContext);

          /* Held until the locks are dropped: an observer that sets a second
           * observed object would otherwise deadlock against a thread taking
           * the same two objects in the other order.  The delivery is counted
           * so that a willChange elsewhere does not refill the dictionary
           * while it is being read.  Holding the key path observer holds the
           * observer, the key path and the context with it.
           */
          [keypathObserver beginDelivery];
          pending[count].keypathObserver = [keypathObserver retain];
          pending[count].change = [keypathObserver.pendingChange retain];
          count++;
        }
      [keypathObserver unlockChange];
    }
  [observationInfo popChangeSet];
  [observationInfo unlockChange];

  for (index = 0; index < count; index++)
    {
      _NSKVOKeypathObserver *keypathObserver = pending[index].keypathObserver;

      [keypathObserver.observer
        observeValueForKeyPath: keypathObserver.keypath
                      ofObject: keypathObserver.object
                        change: pending[index].change
                       context: keypathObserver.context];
      [keypathObserver endDelivery];
      [pending[index].change release];
      [keypathObserver release];
    }
  if (pending != held)
    {
      free(pending);
    }
}

static void
_kvoWillSetChange(_NSKVOKeyObserver *keyObserver, void *context)
{
  _NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
  NSKeyValueObservingOptions options = keypathObserver.options;
  NSMutableDictionary *change = keypathObserver.pendingChange;

  /* An observer that asked for no old, new or prior value is handed the same
   * one entry every time, so it is handed a shared dictionary rather than one
   * emptied and refilled per change.
   */
  if (0 == (options & (NSKeyValueObservingOptionOld
    | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionPrior)))
    {
      if (change != (NSMutableDictionary *)_kvoSettingChange)
        {
          keypathObserver.pendingChange
            = (NSMutableDictionary *)_kvoSettingChange;
        }
      return;
    }

  /* Reuse the change dictionary across notifications rather than allocating
   * (and rehashing) a fresh one every time the setter fires.  A delivery in
   * progress is still reading the last one, so that case gets a fresh
   * dictionary instead.
   */
  if (change == nil || change == (NSMutableDictionary *)_kvoSettingChange
    || [keypathObserver isDelivering])
    {
      change = [[NSMutableDictionary alloc] initWithCapacity: 3];
      keypathObserver.pendingChange = change;
      [change release];
    }
  else
    {
      [change removeAllObjects];
    }

  [change setObject:[NSNumber numberWithUnsignedInteger: NSKeyValueChangeSetting]
             forKey:NSKeyValueChangeKindKey];

  if (options & NSKeyValueObservingOptionOld)
    {
      // For to-many mutations, we can't get the old values at indexes
      // that have not yet been inserted.
      id        rootObject = keypathObserver.object;
      NSString *keypath = keypathObserver.keypath;
      id oldValue = [rootObject valueForKeyPath:keypath] ?: [NSNull null];
      [change setObject: oldValue forKey: NSKeyValueChangeOldKey];
    }
}

- (void) willChangeValueForKey: (NSString *)key
{
  _NSKVOObservationInfo *info
    = (_NSKVOObservationInfo *) [self observationInfo];

  if (info)
    {
      _dispatchWillChange(info, self, key, _kvoWillSetChange, NULL);
    }
}

static void
_kvoDidSetChange(_NSKVOKeyObserver *keyObserver, void *context)
{
  _NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
  NSKeyValueObservingOptions options = keypathObserver.options;
  NSMutableDictionary       *change = keypathObserver.pendingChange;
  if ((options & NSKeyValueObservingOptionNew) &&
      [[change objectForKey: NSKeyValueChangeKindKey] integerValue]
        != NSKeyValueChangeRemoval)
    {
      NSString *keypath = keypathObserver.keypath;
      id        rootObject = keypathObserver.object;
      id newValue = [rootObject valueForKeyPath:keypath] ?: [NSNull null];

      [change setObject: newValue forKey: NSKeyValueChangeNewKey];
    }
}

- (void) didChangeValueForKey: (NSString *)key
{
  _NSKVOObservationInfo *info
    = (_NSKVOObservationInfo *) [self observationInfo];

  if (info)
    {
      _dispatchDidChange(info, self, key, _kvoDidSetChange, NULL);
    }
}

struct _kvoIndexedWillContext
{
  NSKeyValueChange	*kind;
  NSIndexSet		*indexes;
  id			 object;
  NSString		*key;
};
static void
_kvoWillIndexedChange(_NSKVOKeyObserver *keyObserver, void *context)
{
  struct _kvoIndexedWillContext *ctx
    = (struct _kvoIndexedWillContext *) context;
  NSMutableDictionary   *change = [NSMutableDictionary
    dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger: *ctx->kind],
                                 NSKeyValueChangeKindKey,
                                 ctx->indexes, NSKeyValueChangeIndexesKey,
                                 nil];
  _NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
  NSKeyValueObservingOptions options = keypathObserver.options;
  id                         rootObject = keypathObserver.object;

  // The reference platform does not support to-many mutations on nested
  // keypaths. We have to treat them as to-one mutations to support
  // aggregate functions.
  if (*ctx->kind != NSKeyValueChangeSetting
      && keyObserver.restOfKeypathObserver)
    {
      // This only needs to be done in willChange because didChange
      // derives from the existing changeset.
      [change setObject: [NSNumber numberWithUnsignedInteger:
                           (*ctx->kind = NSKeyValueChangeSetting)]
                 forKey: NSKeyValueChangeKindKey];

      // Make change Old/New values the entire collection rather than a
      // to-many change with objectsAtIndexes:
      [change removeObjectForKey:NSKeyValueChangeIndexesKey];
    }

  if ((options & NSKeyValueObservingOptionOld)
      && *ctx->kind != NSKeyValueChangeInsertion)
    {
      // For to-many mutations, we can't get the old values at indexes
      // that have not yet been inserted.
      NSString *keypath = keypathObserver.keypath;
      [change setObject: _valueForPendingChangeAtIndexes(ctx->object, ctx->key,
                           keypath, rootObject, keyObserver, change)
                 forKey: NSKeyValueChangeOldKey];
    }

  keypathObserver.pendingChange = change;
}

- (void) willChange: (NSKeyValueChange)changeKind
    valuesAtIndexes: (NSIndexSet *)indexes
             forKey: (NSString *)key
{
  NSKeyValueChange kind = changeKind;
  _NSKVOObservationInfo *info
    = (_NSKVOObservationInfo *) [self observationInfo];

  if (info)
    {
      struct _kvoIndexedWillContext ctx = { &kind, indexes, self, key };
      _dispatchWillChange(info, self, key, _kvoWillIndexedChange, &ctx);
    }
}

struct _kvoIndexedDidContext
{
  id		 object;
  NSString	*key;
};
static void
_kvoDidIndexedChange(_NSKVOKeyObserver *keyObserver, void *context)
{
  struct _kvoIndexedDidContext *ctx
    = (struct _kvoIndexedDidContext *) context;
  _NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
  NSKeyValueObservingOptions options = keypathObserver.options;
  NSMutableDictionary       *change = keypathObserver.pendingChange;
  if ((options & NSKeyValueObservingOptionNew) &&
      [[change objectForKey: NSKeyValueChangeKindKey] integerValue]
        != NSKeyValueChangeRemoval)
    {
      // For to-many mutations, we can't get the new values at indexes
      // that have been deleted.
      id        rootObject = keypathObserver.object;
      NSString *keypath = keypathObserver.keypath;
      id        newValue
        = _valueForPendingChangeAtIndexes(ctx->object, ctx->key, keypath,
                                          rootObject, keyObserver, change);

      [change setObject: newValue forKey: NSKeyValueChangeNewKey];
    }
}

- (void) didChange: (NSKeyValueChange)changeKind
   valuesAtIndexes: (NSIndexSet *)indexes
            forKey: (NSString *)key
{
  _NSKVOObservationInfo *info
    = (_NSKVOObservationInfo *) [self observationInfo];

  if (info)
    {
      struct _kvoIndexedDidContext ctx = { self, key };
      _dispatchDidChange(info, self, key, _kvoDidIndexedChange, &ctx);
    }
}

// Need to know the previous value for the set if we need to find the values
// added
static const NSString *_NSKeyValueChangeOldSetValue
  = @"_NSKeyValueChangeOldSetValue";

struct _kvoSetWillContext
{
  NSKeyValueChange		changeKind;
  NSKeyValueSetMutationKind	mutationKind;
  NSSet				*objects;
};
static void
_kvoWillSetMutation(_NSKVOKeyObserver *keyObserver, void *context)
{
  struct _kvoSetWillContext *ctx = (struct _kvoSetWillContext *) context;
  NSMutableDictionary *change =
    [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInteger: ctx->changeKind]
                                       forKey:NSKeyValueChangeKindKey];
  _NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
  NSKeyValueObservingOptions options = keypathObserver.options;
  id                         rootObject = keypathObserver.object;
  NSString                  *keypath = keypathObserver.keypath;

  NSSet *oldValues = [rootObject valueForKeyPath:keypath];
  if ((options & NSKeyValueObservingOptionOld)
      && ctx->changeKind != NSKeyValueChangeInsertion)
    {
      NSMutableSet *removed = [NSMutableSet set];

      // The old value should only contain values which are removed from
      // the original collection.
      switch (ctx->mutationKind)
        {
        case NSKeyValueMinusSetMutation:
          // The only objects which were removed are those both in
          // oldValues and objects.
          for (id obj in oldValues)
            {
              if ([ctx->objects containsObject:obj])
                [removed addObject:obj];
            }
          break;
        case NSKeyValueIntersectSetMutation:
        case NSKeyValueSetSetMutation:
        default:
          // The only objects which were removed are those in oldValues
          // and NOT in objects.
          for (id obj in oldValues)
            {
              if (![ctx->objects member:obj])
                [removed addObject:obj];
            }
          break;
        }
      [change setObject: removed forKey: NSKeyValueChangeOldKey];
    }

  if (options & NSKeyValueObservingOptionNew)
    {
      // Save old value in change dictionary for
      // didChangeValueForKey:withSetMutation:usingObjects: to use for
      // determining added objects Only needed if observer wants New
      // value.  A nil value would previously have been a no-op via the
      // dictionary subscript, so guard it here.
      NSSet *oldCopy = [[oldValues copy] autorelease];

      if (oldCopy != nil)
        {
          [change setObject: oldCopy forKey: _NSKeyValueChangeOldSetValue];
        }
    }

  keypathObserver.pendingChange = change;
}

- (void)willChangeValueForKey: (NSString *)key
              withSetMutation: (NSKeyValueSetMutationKind)mutationKind
                 usingObjects: (NSSet *)objects
{
  _NSKVOObservationInfo *info
    = (_NSKVOObservationInfo *) [self observationInfo];

  if (info)
    {
      struct _kvoSetWillContext ctx
        = { _changeFromSetMutationKind(mutationKind), mutationKind, objects };
      _dispatchWillChange(info, self, key, _kvoWillSetMutation, &ctx);
    }
}

struct _kvoSetDidContext
{
  NSKeyValueSetMutationKind	mutationKind;
  NSSet				*objects;
};
static void
_kvoDidSetMutation(_NSKVOKeyObserver *keyObserver, void *context)
{
  struct _kvoSetDidContext *ctx = (struct _kvoSetDidContext *) context;
  _NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
  NSKeyValueChange changeKind = _changeFromSetMutationKind(ctx->mutationKind);
  NSKeyValueObservingOptions options = keypathObserver.options;

  if ((options & NSKeyValueObservingOptionNew)
      && changeKind != NSKeyValueChangeRemoval)
    {
      // New values only exist for inserting or replacing, not removing
      NSMutableDictionary *change = keypathObserver.pendingChange;
      NSSet *oldValues = [change objectForKey: _NSKeyValueChangeOldSetValue];
      NSMutableSet *added = [NSMutableSet set];

      // The new value should only contain values which are added to the
      // original set The only objects added are those in objects but
      // NOT in oldValues
      for (id obj in ctx->objects)
        {
          if (![oldValues member:obj])
            [added addObject:obj];
        }

      [change setObject: added forKey: NSKeyValueChangeNewKey];
      [change removeObjectForKey:_NSKeyValueChangeOldSetValue];
    }
}

- (void)didChangeValueForKey: (NSString *)key
             withSetMutation: (NSKeyValueSetMutationKind)mutationKind
                usingObjects: (NSSet *)objects
{
  _NSKVOObservationInfo *info
    = (_NSKVOObservationInfo *) [self observationInfo];

  if (info)
    {
      struct _kvoSetDidContext ctx = { mutationKind, objects };
      _dispatchDidChange(info, self, key, _kvoDidSetMutation, &ctx);
    }
}
@end

#pragma endregion

#pragma region KVO Core Implementation - Private Access

@implementation
NSObject (NSKeyValueObservingPrivate)

- (Class)_underlyingClass
{
  return [self class];
}

struct _kvoNotifyContext
{
  id	oldValue;
  id	newValue;
};
static void
_kvoWillNotifyChange(_NSKVOKeyObserver *keyObserver, void *context)
{
  struct _kvoNotifyContext *ctx = (struct _kvoNotifyContext *) context;
  NSMutableDictionary *change =
    [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInteger: NSKeyValueChangeSetting]
                                       forKey:NSKeyValueChangeKindKey];
  _NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
  NSKeyValueObservingOptions options = keypathObserver.options;

  if (options & NSKeyValueObservingOptionOld)
    {
      [change setObject: (ctx->oldValue ? ctx->oldValue : [NSNull null])
                 forKey: NSKeyValueChangeOldKey];
    }

  keypathObserver.pendingChange = change;
}
static void
_kvoDidNotifyChange(_NSKVOKeyObserver *keyObserver, void *context)
{
  struct _kvoNotifyContext *ctx = (struct _kvoNotifyContext *) context;
  _NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
  NSKeyValueObservingOptions options = keypathObserver.options;
  NSMutableDictionary       *change = keypathObserver.pendingChange;
  if ((options & NSKeyValueObservingOptionNew) &&
      [[change objectForKey: NSKeyValueChangeKindKey] integerValue]
        != NSKeyValueChangeRemoval)
    {
      [change setObject: (ctx->newValue ? ctx->newValue : [NSNull null])
                 forKey: NSKeyValueChangeNewKey];
    }
}

- (void)_notifyObserversOfChangeForKey: (NSString *)key
                              oldValue: (id)oldValue
                              newValue: (id)newValue
{
  _NSKVOObservationInfo *info
    = (_NSKVOObservationInfo *) [self observationInfo];

  if (info)
    {
      struct _kvoNotifyContext ctx = { oldValue, newValue };
      _dispatchWillChange(info, self, key, _kvoWillNotifyChange, &ctx);
      _dispatchDidChange(info, self, key, _kvoDidNotifyChange, &ctx);
    }
}

@end

#pragma endregion

#pragma region KVO Core Implementation - NSArray category

@implementation
NSArray (NSKeyValueObserving)

- (void)addObserver: (id)observer
         forKeyPath: (NSString *)keyPath
            options: (NSKeyValueObservingOptions)options
            context: (void *)context
{
  NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

- (void)removeObserver: (id)observer
            forKeyPath: (NSString *)keyPath
               context: (void *)context
{
  NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

- (void)removeObserver: (id)observer forKeyPath:(NSString *)keyPath
{
  NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

- (void) addObserver: (NSObject*)observer
  toObjectsAtIndexes: (NSIndexSet*)indexes
          forKeyPath: (NSString*)keyPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)context
{
  NSUInteger index = [indexes firstIndex];

  while (index != NSNotFound)
    {
      [[self objectAtIndex:index] addObserver:observer
                                   forKeyPath:keyPath
                                      options:options
                                      context:context];
      index = [indexes indexGreaterThanIndex:index];
    }
}

- (void) removeObserver: (NSObject*)observer
   fromObjectsAtIndexes: (NSIndexSet*)indexes
             forKeyPath: (NSString*)keyPath
                context: (void*)context
{
  NSUInteger index = [indexes firstIndex];

  while (index != NSNotFound)
    {
      [[self objectAtIndex:index] removeObserver:observer
                                      forKeyPath:keyPath
                                         context:context];
      index = [indexes indexGreaterThanIndex:index];
    }
}

- (void)removeObserver: (NSObject *)observer
  fromObjectsAtIndexes: (NSIndexSet *)indexes
            forKeyPath: (NSString *)keyPath
{
  [self removeObserver:observer
    fromObjectsAtIndexes:indexes
              forKeyPath:keyPath
                 context:NULL];
}

@end

#pragma endregion

#pragma region KVO Core Implementation - NSSet category

@implementation
NSSet (NSKeyValueObserving)

- (void)addObserver: (id)observer
         forKeyPath: (NSString *)keyPath
            options: (NSKeyValueObservingOptions)options
            context: (void *)context
{
  NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

- (void)removeObserver: (id)observer
            forKeyPath: (NSString *)keyPath
               context: (void *)context
{
  NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

- (void)removeObserver: (id)observer forKeyPath:(NSString *)keyPath
{
  NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

@end

#pragma endregion

#pragma region KVO forwarding - NSProxy category

@implementation
NSProxy (NSKeyValueObserving)

- (Class)_underlyingClass
{
  // Retrieve the underlying class via KVC
  // Note that we assume that the class is KVC-compliant, when KVO is used
  return [(NSObject *)self valueForKey: @"class"];
}

@end

#pragma endregion

//******************************************************************************
//
// Copyright (c) Microsoft. All rights reserved.
// Copyright (c) 2006-2009 Johannes Fortmann, Cocotron Contributors et al.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#import "common.h"
#import "NSKeyValueObserving-Internal.h"
// #import "NSObject_NSKeyValueCoding-Internal.h"
#import <objc/objc-arc.h>
#import <stdatomic.h>

typedef void (^DispatchChangeBlock)(_NSKVOKeyObserver *);

NSString *
_NSKVCSplitKeypath(NSString *keyPath, NSString *__autoreleasing *pRemainder)
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
@interface
_NSKVOKeyObserver ()
{
  _Atomic(BOOL) _isRemoved;
}
@end

@implementation _NSKVOKeyObserver
- (instancetype)initWithObject:(id)object
	       keypathObserver:(_NSKVOKeypathObserver *)keypathObserver
			   key:(NSString *)key
		 restOfKeypath:(NSString *)restOfKeypath
	     affectedObservers:(NSArray *)affectedObservers
{
  if (self = [super init])
    {
      _object = object;
      _keypathObserver = [keypathObserver retain];
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
  [_affectedObservers release];
  [super dealloc];
}

- (BOOL)isRemoved
{
  return _isRemoved;
}

- (void)setIsRemoved:(BOOL)removed
{
  _isRemoved = removed;
}
@end
#pragma endregion

#pragma region Keypath Observer
@interface
_NSKVOKeypathObserver ()
{
  _Atomic(int) _changeDepth;
}
@end

@implementation _NSKVOKeypathObserver
- (instancetype)initWithObject:(id)object
		      observer:(id)observer
		       keyPath:(NSString *)keypath
		       options:(NSKeyValueObservingOptions)options
		       context:(void *)context
{
  if (self = [super init])
    {
      _object = object;
      _observer = observer;
      _keypath = [keypath copy];
      _options = options;
      _context = context;
    }
  return self;
}

- (void)dealloc
{
  [_keypath release];
  [_pendingChange release];
  [super dealloc];
}

- (id)observer
{
  return _observer;
}

- (BOOL)pushWillChange
{
  // return std::atomic_fetch_add(&_changeDepth, 1) == 0;
  return atomic_fetch_add(&_changeDepth, 1) == 0;
}

- (BOOL)popDidChange
{
  // return std::atomic_fetch_sub(&_changeDepth, 1) == 1;
  return atomic_fetch_sub(&_changeDepth, 1) == 1;
}
@end
#pragma endregion

#pragma region Object - level Observation Info
@implementation _NSKVOObservationInfo
- (instancetype)init
{
  if (self = [super init])
    {
      _keyObserverMap = [[NSMutableDictionary alloc] initWithCapacity:1];
      GS_MUTEX_INIT(_lock);
    }
  return self;
}

- (void)dealloc
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

  GS_MUTEX_DESTROY(_lock);

  [super dealloc];
}

- (void)pushDependencyStack
{
  GS_MUTEX_LOCK(_lock);
  if (_dependencyDepth == 0)
    {
      _existingDependentKeys = [NSMutableSet new];
    }
  ++_dependencyDepth;
  GS_MUTEX_UNLOCK(_lock);
}

- (BOOL)lockDependentKeypath:(NSString *)keypath
{
  GS_MUTEX_LOCK(_lock);
  if ([_existingDependentKeys containsObject:keypath])
    {
      GS_MUTEX_UNLOCK(_lock);
      return NO;
    }
  [_existingDependentKeys addObject:keypath];
  GS_MUTEX_UNLOCK(_lock);
  return YES;
}

- (void)popDependencyStack
{
  GS_MUTEX_LOCK(_lock);
  --_dependencyDepth;
  if (_dependencyDepth == 0)
    {
      [_existingDependentKeys release];
      _existingDependentKeys = nil;
    }
  GS_MUTEX_UNLOCK(_lock);
}

- (void)addObserver:(_NSKVOKeyObserver *)observer
{
  NSString	 *key = observer.key;
  NSMutableArray *observersForKey = nil;
  GS_MUTEX_LOCK(_lock);
  observersForKey = [_keyObserverMap objectForKey:key];
  if (!observersForKey)
    {
      observersForKey = [NSMutableArray array];
      [_keyObserverMap setObject:observersForKey forKey:key];
    }
  [observersForKey addObject:observer];
  GS_MUTEX_UNLOCK(_lock);
}

- (void)removeObserver:(_NSKVOKeyObserver *)observer
{
  GS_MUTEX_LOCK(_lock);
  NSString	 *key = observer.key;
  NSMutableArray *observersForKey = [_keyObserverMap objectForKey:key];
  [observersForKey removeObject:observer];
  observer.isRemoved = true;
  if (observersForKey.count == 0)
    {
      [_keyObserverMap removeObjectForKey:key];
    }
  GS_MUTEX_UNLOCK(_lock);
}

- (NSArray *)observersForKey:(NSString *)key
{
  GS_MUTEX_LOCK(_lock);
  NSArray *result = [[[_keyObserverMap objectForKey:key] copy] autorelease];
  GS_MUTEX_UNLOCK(_lock);
  return result;
}

- (bool)isEmpty
{
  GS_MUTEX_LOCK(_lock);
  BOOL result = _keyObserverMap.count == 0;
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
		    NSArray		  *affectedObservers);
static void
_removeKeyObserver(_NSKVOKeyObserver *keyObserver);

// Private helper that backs the default implementation of
// keyPathsForValuesAffectingValueForKey: Returns nil instead of constructing an
// empty set if no keyPaths are found Also used internally as a minor
// optimization, to avoid constructing an empty set when it is not needed
static NSSet *
_keyPathsForValuesAffectingValueForKey(Class self, NSString *key)
{
  // This function can be a KVO bottleneck, so it will prefer to use c string
  // manipulation when safe
  NSUInteger keyLength = [key length];
  if (keyLength > 0)
    {
      static const char *const sc_prefix = "keyPathsForValuesAffecting";
      static const size_t      sc_bufferSize = 128;
      static const size_t      sc_prefixLength = strlen(sc_prefix); // 26

      const char *rawKey;
      size_t	  rawKeyLength;
      SEL	  sel;

      // max length of a key that can guaranteed fit in the char buffer,
      // even if UTF16->UTF8 conversion causes length to double, or a null
      // terminator is needed
      static const size_t sc_safeKeyLength
	= (sc_bufferSize - sc_prefixLength) / 2 - 1; // 50

      rawKey = [key UTF8String];
      rawKeyLength = strlen(rawKey);

      if (keyLength <= sc_safeKeyLength)
	{
	  // fast path using c string manipulation, will cover most cases, as
	  // most keyPaths are short
	  char selectorName[sc_bufferSize]
	    = "keyPathsForValuesAffecting"; // 26 chars
	  selectorName[sc_prefixLength] = toupper(rawKey[0]);
	  // Copy the rest of the key, including the null terminator
	  memcpy(&selectorName[sc_prefixLength + 1], &rawKey[1], rawKeyLength);
	  sel = sel_registerName(selectorName);
	}
      else // Guaranteed path for long keyPaths
	{
	  size_t keyLength;
	  size_t bufferSize;
	  char	*selectorName;

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
    }
  return nil;
}

// Add all observers with declared dependencies on this one:
// * All keypaths that could trigger a change (keypaths for values affecting
// us).
// * The head of the remaining keypath.
static void
_addNestedObserversAndOptionallyDependents(_NSKVOKeyObserver *keyObserver,
					   bool		      dependents)
{
  id			 object = keyObserver.object;
  NSString		*key = keyObserver.key;
  _NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
  _NSKVOObservationInfo *observationInfo
    = (__bridge _NSKVOObservationInfo *) [object observationInfo]
	?: _createObservationInfoForObject(object);

  // Aggregate all keys whose values will affect us.
  if (dependents)
    {
      NSSet *valueInfluencingKeys
	= _keyPathsForValuesAffectingValueForKey([object class], key);
      if (valueInfluencingKeys.count > 0)
	{
	  // affectedKeyObservers is the list of observers that must be notified
	  // of changes. If we have descendants, we have to add ourselves to the
	  // growing list of affected keys. If not, we must pass it along
	  // unmodified. (This is a minor optimization: we don't need to signal
	  // for our own reconstruction
	  //  if we have no subpath observers.)
	  NSArray *affectedKeyObservers
	    = (keyObserver.restOfKeypath
		 ? ([keyObserver.affectedObservers
		      arrayByAddingObject:keyObserver]
		      ?: [NSArray arrayWithObject:keyObserver])
		 : keyObserver.affectedObservers);

	  [observationInfo pushDependencyStack];
	  [observationInfo
	    lockDependentKeypath:keyObserver.key]; // Don't allow our own key to
						   // be recreated.

	  NSMutableArray *dependentObservers =
	    [NSMutableArray arrayWithCapacity:[valueInfluencingKeys count]];
	  for (NSString *dependentKeypath in valueInfluencingKeys)
	    {
	      if ([observationInfo lockDependentKeypath:dependentKeypath])
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

	  [observationInfo popDependencyStack];
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
  if (keyObserver.restOfKeypath && !keyObserver.restOfKeypathObserver)
    {
      keyObserver.restOfKeypathObserver
	= _addKeypathObserver([object valueForKey:key],
			      keyObserver.restOfKeypath, keypathObserver,
			      keyObserver.affectedObservers);
    }

  // Back-propagation of changes.
  // This is where a value-affecting key signals to its dependent that it should
  // be reconstructed.
  for (_NSKVOKeyObserver *affectedObserver in keyObserver.affectedObservers)
    {
      if (!affectedObserver.restOfKeypathObserver)
	{
	  affectedObserver.restOfKeypathObserver
	    = _addKeypathObserver([affectedObserver.object
				    valueForKey:affectedObserver.key],
				  affectedObserver.restOfKeypath,
				  affectedObserver.keypathObserver,
				  affectedObserver.affectedObservers);
	}
    }
}

static void
_addKeyObserver(_NSKVOKeyObserver *keyObserver)
{
  id object = keyObserver.object;
  _NSKVOEnsureKeyWillNotify(object, keyObserver.key);
  _NSKVOObservationInfo *observationInfo
    = (__bridge _NSKVOObservationInfo *) [object observationInfo]
	?: _createObservationInfoForObject(object);
  [observationInfo addObserver:keyObserver];
}

static _NSKVOKeyObserver *
_addKeypathObserver(id object, NSString *keypath,
		    _NSKVOKeypathObserver *keyPathObserver,
		    NSArray		  *affectedObservers)
{
  if (!object)
    {
      return nil;
    }
  NSString *key = nil;
  NSString *restOfKeypath;
  key = _NSKVCSplitKeypath(keypath, &restOfKeypath);

  _NSKVOKeyObserver *keyObserver =
    [[[_NSKVOKeyObserver alloc] initWithObject:object
			       keypathObserver:keyPathObserver
					   key:key
				 restOfKeypath:restOfKeypath
			     affectedObservers:affectedObservers] autorelease];

  if (object)
    {
      _addNestedObserversAndOptionallyDependents(keyObserver, true);
      _addKeyObserver(keyObserver);
    }

  return keyObserver;
}
#pragma endregion

#pragma region Observer / Key Deregistration
static void
_removeNestedObserversAndOptionallyDependents(_NSKVOKeyObserver *keyObserver,
					      bool		 dependents)
{
  if (keyObserver.restOfKeypathObserver)
    {
      // Destroy the subpath observer recursively.
      _removeKeyObserver(keyObserver.restOfKeypathObserver);
      keyObserver.restOfKeypathObserver = nil;
    }

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
	  _removeKeyObserver(affectedObserver.restOfKeypathObserver);
	  affectedObserver.restOfKeypathObserver = nil;
	}
    }
}

static void
_removeKeyObserver(_NSKVOKeyObserver *keyObserver)
{
  if (!keyObserver)
    {
      return;
    }

  _NSKVOObservationInfo *observationInfo
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
  NSString *key = nil;
  NSString *restOfKeypath;
  key = _NSKVCSplitKeypath(keypath, &restOfKeypath);

  _NSKVOObservationInfo *observationInfo
    = (_NSKVOObservationInfo *) [object observationInfo];
  for (_NSKVOKeyObserver *keyObserver in [observationInfo observersForKey:key])
    {
      _NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
      if (keypathObserver.observer == observer
	  && keypathObserver.object == object &&
	  [keypathObserver.keypath isEqual:keypath]
	  && (!context || keypathObserver.context == context))
	{
	  _removeKeyObserver(keyObserver);
	  return;
	}
    }

  [NSException raise:NSInvalidArgumentException
	      format:@"Cannot remove observer %@ for keypath \"%@\" from %@ as "
		     @"it is not a registered observer.",
		     observer, keypath, object];
}
#pragma endregion

#pragma region KVO Core Implementation - NSObject category

@implementation
NSObject (NSKeyValueObserving)
/**
@Status Interoperable
*/
- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary<NSString *, id> *)change
		       context:(void *)context
{
  [NSException raise:NSInternalInconsistencyException
	      format:@"A key-value observation notification fired, but nobody "
		     @"responded to it: object %@, keypath %@, change %@.",
		     object, keyPath, change];
}

static void *s_kvoObservationInfoAssociationKey; // has no value; pointer used
						 // as an association key.

/**
@Status Interoperable
*/
- (void *)observationInfo
{
  return (__bridge void *)
    objc_getAssociatedObject(self, &s_kvoObservationInfoAssociationKey);
}

/**
@Status Interoperable
*/
- (void)setObservationInfo:(void *)observationInfo
{
  objc_setAssociatedObject(self, &s_kvoObservationInfoAssociationKey,
			   (__bridge id) observationInfo,
			   OBJC_ASSOCIATION_RETAIN);
}

/**
@Status Interoperable
*/
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
  if ([key length] > 0)
    {
      static const char *const sc_prefix = "automaticallyNotifiesObserversOf";
      static const size_t      sc_prefixLength = strlen(sc_prefix); // 32
      const char	      *rawKey = [key UTF8String];
      size_t		       keyLength = strlen(rawKey);
      size_t		       bufferSize = sc_prefixLength + keyLength + 1;
      char		      *selectorName = (char *) malloc(bufferSize);
      memcpy(selectorName, sc_prefix, sc_prefixLength);
      selectorName[sc_prefixLength] = toupper(rawKey[0]);
      memcpy(&selectorName[sc_prefixLength + 1], &rawKey[1],
	     keyLength); // copy keyLength characters to include terminating
			 // NULL from rawKey
      SEL sel = sel_registerName(selectorName);
      free(selectorName);
      if ([self respondsToSelector:sel])
	{
	  return ((BOOL(*)(id, SEL)) objc_msgSend)(self, sel);
	}
    }
  return YES;
}

/**
@Status Interoperable
*/
+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
  return _keyPathsForValuesAffectingValueForKey(self, key) ?: [NSSet set];
}

/**
@Status Interoperable
*/
- (void)addObserver:(id)observer
	 forKeyPath:(NSString *)keyPath
	    options:(NSKeyValueObservingOptions)options
	    context:(void *)context
{
  _NSKVOKeypathObserver *keypathObserver =
    [[[_NSKVOKeypathObserver alloc] initWithObject:self
					  observer:observer
					   keyPath:keyPath
					   options:options
					   context:context] autorelease];
  _NSKVOKeyObserver *rootObserver
    = _addKeypathObserver(self, keyPath, keypathObserver, nil);
  rootObserver.root = true;

  if ((options & NSKeyValueObservingOptionInitial))
    {
      NSMutableDictionary *change = [NSMutableDictionary
	dictionaryWithObjectsAndKeys:@(NSKeyValueChangeSetting),
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

/**
@Status Interoperable
*/
- (void)removeObserver:(id)observer
	    forKeyPath:(NSString *)keyPath
	       context:(void *)context
{
  _removeKeypathObserver(self, keyPath, observer, context);
  _NSKVOObservationInfo *observationInfo
    = (__bridge _NSKVOObservationInfo *) [self observationInfo];
  if ([observationInfo isEmpty])
    {
      // TODO: was nullptr prior
      [self setObservationInfo:nil];
    }
}

/**
@Status Interoperable
*/
- (void)removeObserver:(id)observer forKeyPath:(NSString *)keyPath
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
				NSDictionary	  *pendingChange)
{
  id	      value = nil;
  NSIndexSet *indexes = pendingChange[NSKeyValueChangeIndexesKey];
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
_dispatchWillChange(id notifyingObject, NSString *key,
		    DispatchChangeBlock block)
{
  _NSKVOObservationInfo *observationInfo
    = (__bridge _NSKVOObservationInfo *) [notifyingObject observationInfo];
  for (_NSKVOKeyObserver *keyObserver in [observationInfo observersForKey:key])
    {
      if (keyObserver.isRemoved)
	{
	  continue;
	}

      // Skip any keypaths that are in the process of changing.
      _NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
      if ([keypathObserver pushWillChange])
	{
	  // Call into the lambda function, which will do the actual set-up for
	  // pendingChanges
	  block(keyObserver);

	  NSKeyValueObservingOptions options = keypathObserver.options;
	  if (options & NSKeyValueObservingOptionPrior)
	    {
	      NSMutableDictionary *change = keypathObserver.pendingChange;
	      [change setObject:@(YES)
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
      _removeNestedObserversAndOptionallyDependents(keyObserver, false);
    }
}

static void
_dispatchDidChange(id notifyingObject, NSString *key, DispatchChangeBlock block)
{
  _NSKVOObservationInfo *observationInfo
    = (__bridge _NSKVOObservationInfo *) [notifyingObject observationInfo];
  NSArray<_NSKVOKeyObserver *> *observers =
    [observationInfo observersForKey:key];
  for (_NSKVOKeyObserver *keyObserver in [observers reverseObjectEnumerator])
    {
      if (keyObserver.isRemoved)
	{
	  continue;
	}

      // This must happen regardless of whether we are currently notifying.
      _addNestedObserversAndOptionallyDependents(keyObserver, false);

      // Skip any keypaths that are in the process of changing.
      _NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
      if ([keypathObserver popDidChange])
	{
	  // Call into lambda, which will do set-up for finalizing changes
	  // dictionary
	  block(keyObserver);

	  id		       observer = keypathObserver.observer;
	  NSString	      *keypath = keypathObserver.keypath;
	  id		       rootObject = keypathObserver.object;
	  NSMutableDictionary *change = keypathObserver.pendingChange;
	  void		      *context = keypathObserver.context;
	  [observer observeValueForKeyPath:keypath
				  ofObject:rootObject
				    change:change
				   context:context];
	  keypathObserver.pendingChange = nil;
	}
    }
}

/**
@Status Interoperable
*/
- (void)willChangeValueForKey:(NSString *)key
{
  if ([self observationInfo])
    {
      _dispatchWillChange(self, key, ^(_NSKVOKeyObserver *keyObserver) {
	NSMutableDictionary *change =
	  [NSMutableDictionary dictionaryWithObject:@(NSKeyValueChangeSetting)
					     forKey:NSKeyValueChangeKindKey];
	_NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
	NSKeyValueObservingOptions options = keypathObserver.options;

	if (options & NSKeyValueObservingOptionOld)
	  {
	    // For to-many mutations, we can't get the old values at indexes
	    // that have not yet been inserted.
	    id	      rootObject = keypathObserver.object;
	    NSString *keypath = keypathObserver.keypath;
	    id oldValue = [rootObject valueForKeyPath:keypath] ?: [NSNull null];
	    change[NSKeyValueChangeOldKey] = oldValue;
	  }

	keypathObserver.pendingChange = change;
      });
    }
}

/**
@Status Interoperable
*/
- (void)didChangeValueForKey:(NSString *)key
{
  if ([self observationInfo])
    {
      _dispatchDidChange(self, key, ^(_NSKVOKeyObserver *keyObserver) {
	_NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
	NSKeyValueObservingOptions options = keypathObserver.options;
	NSMutableDictionary	  *change = keypathObserver.pendingChange;
	if ((options & NSKeyValueObservingOptionNew) &&
	    [change[NSKeyValueChangeKindKey] integerValue]
	      != NSKeyValueChangeRemoval)
	  {
	    NSString *keypath = keypathObserver.keypath;
	    id	      rootObject = keypathObserver.object;
	    id newValue = [rootObject valueForKeyPath:keypath] ?: [NSNull null];

	    change[NSKeyValueChangeNewKey] = newValue;
	  }
      });
    }
}

/**
@Status Interoperable
*/
- (void)willChange:(NSKeyValueChange)changeKind
   valuesAtIndexes:(NSIndexSet *)indexes
	    forKey:(NSString *)key
{
  __block NSKeyValueChange kind = changeKind;
  if ([self observationInfo])
    {
      _dispatchWillChange(self, key, ^(_NSKVOKeyObserver *keyObserver) {
	NSMutableDictionary   *change = [NSMutableDictionary
	    dictionaryWithObjectsAndKeys:@(kind), NSKeyValueChangeKindKey,
					 indexes, NSKeyValueChangeIndexesKey,
					 nil];
	_NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
	NSKeyValueObservingOptions options = keypathObserver.options;
	id			   rootObject = keypathObserver.object;

	// The reference platform does not support to-many mutations on nested
	// keypaths. We have to treat them as to-one mutations to support
	// aggregate functions.
	if (kind != NSKeyValueChangeSetting
	    && keyObserver.restOfKeypathObserver)
	  {
	    // This only needs to be done in willChange because didChange
	    // derives from the existing changeset.
	    change[NSKeyValueChangeKindKey] = @(kind = NSKeyValueChangeSetting);

	    // Make change Old/New values the entire collection rather than a
	    // to-many change with objectsAtIndexes:
	    [change removeObjectForKey:NSKeyValueChangeIndexesKey];
	  }

	if ((options & NSKeyValueObservingOptionOld)
	    && kind != NSKeyValueChangeInsertion)
	  {
	    // For to-many mutations, we can't get the old values at indexes
	    // that have not yet been inserted.
	    NSString *keypath = keypathObserver.keypath;
	    change[NSKeyValueChangeOldKey]
	      = _valueForPendingChangeAtIndexes(self, key, keypath, rootObject,
						keyObserver, change);
	  }

	keypathObserver.pendingChange = change;
      });
    }
}

/**
@Status Interoperable
*/
- (void)didChange:(NSKeyValueChange)changeKind
  valuesAtIndexes:(NSIndexSet *)indexes
	   forKey:(NSString *)key
{
  if ([self observationInfo])
    {
      _dispatchDidChange(self, key, ^(_NSKVOKeyObserver *keyObserver) {
	_NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
	NSKeyValueObservingOptions options = keypathObserver.options;
	NSMutableDictionary	  *change = keypathObserver.pendingChange;
	if ((options & NSKeyValueObservingOptionNew) &&
	    [change[NSKeyValueChangeKindKey] integerValue]
	      != NSKeyValueChangeRemoval)
	  {
	    // For to-many mutations, we can't get the new values at indexes
	    // that have been deleted.
	    id	      rootObject = keypathObserver.object;
	    NSString *keypath = keypathObserver.keypath;
	    id	      newValue
	      = _valueForPendingChangeAtIndexes(self, key, keypath, rootObject,
						keyObserver, change);

	    change[NSKeyValueChangeNewKey] = newValue;
	  }
      });
    }
}

// Need to know the previous value for the set if we need to find the values
// added
static const NSString *_NSKeyValueChangeOldSetValue
  = @"_NSKeyValueChangeOldSetValue";

/**
 @Status Interoperable
*/
- (void)willChangeValueForKey:(NSString *)key
	      withSetMutation:(NSKeyValueSetMutationKind)mutationKind
		 usingObjects:(NSSet *)objects
{
  if ([self observationInfo])
    {
      NSKeyValueChange changeKind = _changeFromSetMutationKind(mutationKind);
      _dispatchWillChange(self, key, ^(_NSKVOKeyObserver *keyObserver) {
	NSMutableDictionary *change =
	  [NSMutableDictionary dictionaryWithObject:@(changeKind)
					     forKey:NSKeyValueChangeKindKey];
	_NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
	NSKeyValueObservingOptions options = keypathObserver.options;
	id			   rootObject = keypathObserver.object;
	NSString		  *keypath = keypathObserver.keypath;

	NSSet *oldValues = [rootObject valueForKeyPath:keypath];
	if ((options & NSKeyValueObservingOptionOld)
	    && changeKind != NSKeyValueChangeInsertion)
	  {
	    // The old value should only contain values which are removed from
	    // the original dictionary
	    switch (mutationKind)
	      {
	      case NSKeyValueMinusSetMutation:
		// The only objects which were removed are those both in
		// oldValues and objects
		change[NSKeyValueChangeOldKey] =
		  [oldValues objectsPassingTest:^(id obj, BOOL *stop) {
		    return [objects containsObject:obj];
		  }];
		break;
	      case NSKeyValueIntersectSetMutation:
	      case NSKeyValueSetSetMutation:
	      default:
		// The only objects which were removed are those in oldValues
		// and NOT in objects
		change[NSKeyValueChangeOldKey] =
		  [oldValues objectsPassingTest:^BOOL(id obj, BOOL *stop) {
		    return [objects member:obj] ? NO : YES;
		  }];
		break;
	      }
	  }

	if (options & NSKeyValueObservingOptionNew)
	  {
	    // Save old value in change dictionary for
	    // didChangeValueForKey:withSetMutation:usingObjects: to use for
	    // determining added objects Only needed if observer wants New
	    // value
	    change[_NSKeyValueChangeOldSetValue] =
	      [[oldValues copy] autorelease];
	  }

	keypathObserver.pendingChange = change;
      });
    }
}

/**
 @Status Interoperable
*/
- (void)didChangeValueForKey:(NSString *)key
	     withSetMutation:(NSKeyValueSetMutationKind)mutationKind
		usingObjects:(NSSet *)objects
{
  if ([self observationInfo])
    {
      _dispatchDidChange(self, key, ^(_NSKVOKeyObserver *keyObserver) {
	_NSKVOKeypathObserver *keypathObserver = keyObserver.keypathObserver;
	NSKeyValueChange changeKind = _changeFromSetMutationKind(mutationKind);
	NSKeyValueObservingOptions options = keypathObserver.options;

	if ((options & NSKeyValueObservingOptionNew)
	    && changeKind != NSKeyValueChangeRemoval)
	  {
	    // New values only exist for inserting or replacing, not removing
	    NSMutableDictionary *change = keypathObserver.pendingChange;
	    NSSet *oldValues = change[_NSKeyValueChangeOldSetValue];
	    // The new value should only contain values which are added to the
	    // original set The only objects added are those in objects but
	    // NOT in oldValues
	    NSSet *newValue =
	      [objects objectsPassingTest:^BOOL(id obj, BOOL *stop) {
		return [objects member:obj] ? NO : YES;
	      }];

	    change[NSKeyValueChangeNewKey] = newValue;
	    [change removeObjectForKey:_NSKeyValueChangeOldSetValue];
	  }
      });
    }
}
@end

#pragma endregion

#pragma region KVO Core Implementation - NSArray category

@implementation
NSArray (NSKeyValueObserving)

/**
 @Status Interoperable
*/
- (void)addObserver:(id)observer
	 forKeyPath:(NSString *)keyPath
	    options:(NSKeyValueObservingOptions)options
	    context:(void *)context
{
  NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

/**
 @Status Interoperable
*/
- (void)removeObserver:(id)observer
	    forKeyPath:(NSString *)keyPath
	       context:(void *)context
{
  NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

/**
 @Status Interoperable
*/
- (void)removeObserver:(id)observer forKeyPath:(NSString *)keyPath
{
  NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

/**
 @Status Caveat
 @Notes This is a convenience method, no performance gains for using this over
 individual calls to removeObserver to affected objects
*/
- (void)addObserver:(id)observer
  toObjectsAtIndexes:(NSIndexSet *)indexes
	  forKeyPath:(NSString *)keyPath
	     options:(NSKeyValueObservingOptions)options
	     context:(void *)context
{
  [indexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
    [[self objectAtIndex:index] addObserver:observer
				 forKeyPath:keyPath
				    options:options
				    context:context];
  }];
}

/**
 @Status Caveat
 @Notes This is a convenience method, no performance gains for using this over
 individual calls to removeObserver to affected objects
*/
- (void)removeObserver:(id)observer
  fromObjectsAtIndexes:(NSIndexSet *)indexes
	    forKeyPath:(NSString *)keyPath
	       context:(void *)context
{
  [indexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
    [[self objectAtIndex:index] removeObserver:observer
				    forKeyPath:keyPath
				       context:context];
  }];
}

/**
 @Status Caveat
 @Notes This is a convenience method, no performance gains for using this over
 individual calls to removeObserver to affected objects
*/
- (void)removeObserver:(NSObject *)observer
  fromObjectsAtIndexes:(NSIndexSet *)indexes
	    forKeyPath:(NSString *)keyPath
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

/**
 @Status Interoperable
*/
- (void)addObserver:(id)observer
	 forKeyPath:(NSString *)keyPath
	    options:(NSKeyValueObservingOptions)options
	    context:(void *)context
{
  NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

/**
 @Status Interoperable
*/
- (void)removeObserver:(id)observer
	    forKeyPath:(NSString *)keyPath
	       context:(void *)context
{
  NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

/**
 @Status Interoperable
*/
- (void)removeObserver:(id)observer forKeyPath:(NSString *)keyPath
{
  NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

@end

#pragma endregion
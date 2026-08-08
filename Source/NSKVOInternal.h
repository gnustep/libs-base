/**
   NSKVOInternal.h

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

#import "Foundation/NSObject.h"
#import "Foundation/NSString.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSKeyValueObserving.h"
#import "Foundation/NSException.h"

#import "GSPrivate.h"

#if defined(__OBJC2__) || defined(GNUSTEP_BASE_NEW_KVO)

#import "GSPThread.h"

#define NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath)                               \
  do                                                                           \
    {                                                                          \
      [NSException                                                             \
         raise: NSInvalidArgumentException                                     \
        format: @"-[%s %s] is not supported. Key path: %@",                    \
               object_getClassName(self), sel_getName(_cmd), keyPath];         \
  } while (false)

@class _NSKVOKeypathObserver;
@class _NSKVOForwardingRelay;

@interface _NSKVOKeyObserver : NSObject
{
  _NSKVOKeypathObserver	*_keypathObserver;
  _NSKVOKeyObserver     *_restOfKeypathObserver;
  _NSKVOForwardingRelay *_restOfKeypathRelay;
  NSArray               *_dependentObservers;
  id                     _object;
  NSString              *_key;
  NSString              *_restOfKeypath;
  NSArray               *_affectedObservers;
  BOOL                   _root;
  /* Accessed with __atomic_* builtins for portability: GCC does not allow
   * the _Atomic type qualifier on an Objective-C instance variable. */
  BOOL                   _isRemoved;
}
- (instancetype) initWithObject: (id)object
                keypathObserver: (_NSKVOKeypathObserver *)keypathObserver
                            key: (NSString *)key
                  restOfKeypath: (NSString *)restOfKeypath
              affectedObservers: (NSArray *)affectedObservers;
@property (nonatomic, retain) _NSKVOKeypathObserver	*keypathObserver;
@property (nonatomic, retain) _NSKVOKeyObserver     	*restOfKeypathObserver;
@property (nonatomic, retain) _NSKVOForwardingRelay 	*restOfKeypathRelay;
@property (nonatomic, retain) NSArray               	*dependentObservers;
@property (nonatomic, assign) id                     	object;
@property (nonatomic, copy) NSString                	*key;
@property (nonatomic, copy) NSString                	*restOfKeypath;
@property (nonatomic, retain) NSArray               	*affectedObservers;
@property (nonatomic, assign) BOOL                   	root;
@property (nonatomic, readonly) BOOL                 	isRemoved;
@end

@interface _NSKVOKeypathObserver : NSObject
{
  id                         	_object;
  id                         	_observer;
  NSString                  	*_keypath;
  NSKeyValueObservingOptions	_options;
  void                      	*_context;
  NSMutableDictionary       	*_pendingChange;
  int                        	_changeDepth;
  int                        	_deliveryCount;
  gs_mutex_t                 	_changeLock;
}
- (instancetype) initWithObject: (id)object
                       observer: (id)observer
                        keyPath: (NSString *)keypath
                        options: (NSKeyValueObservingOptions)options
                        context: (void *)context;
@property (nonatomic, assign) id                         object;
@property (nonatomic, assign) id                         observer;
@property (nonatomic, copy) NSString                    *keypath;
@property (nonatomic, assign) NSKeyValueObservingOptions options;
@property (nonatomic, assign) void                      *context;

/* Read and written only with -lockChange held, so the accessors do not need
 * to synchronize on their own.
 */
@property (nonatomic, retain) NSMutableDictionary *pendingChange;

/* Held from a willChange to the matching didChange.  Two key paths reached
 * through different objects share one key path observer, so the observed
 * object's own lock does not cover this.
 */
- (void) lockChange;
- (void) unlockChange;

/* Bracket the call to the observer, which happens with no lock held.  The
 * change dictionary is read for the length of that call, so it may not be
 * cleared and refilled by a willChange until every such call has returned.
 */
- (void) beginDelivery;
- (void) endDelivery;
- (BOOL) isDelivering;
@end

/* Observes on behalf of a key path whose intermediate object registers
 * observations on the objects it holds.
 */
@interface _NSKVOForwardingRelay : NSObject
{
  id                     _object;
  NSString              *_keypath;
  _NSKVOKeypathObserver *_keypathObserver;
}
- (instancetype) initWithObject: (id)object
                        keypath: (NSString *)keypath
                keypathObserver: (_NSKVOKeypathObserver *)keypathObserver;
- (void) stop;
@end

@interface _NSKVOObservationInfo : NSObject
{
  NSMutableDictionary	*_keyObserverMap;
  NSInteger             _dependencyDepth;
  NSMutableSet          *_existingDependentKeys;
  NSMutableSet          *_dependencyAncestorKeys;
  gs_mutex_t            _lock;
  gs_mutex_t            _changeLock;
}
- (void) addObserver: (_NSKVOKeyObserver *)observer;
- (instancetype) init;
- (BOOL) isEmpty;
- (NSArray *) observersForKey: (NSString *)key;

/* Held from a willChange to the matching didChange.  The change depth and the
 * pending change of each key path observer are reachable from both, so a
 * second thread setting the same object must not run between them.
 * Recursive: a dependent key notifies while the key it depends on is
 * notifying, on the same thread.
 */
- (void) lockChange;
- (void) unlockChange;
@end

// From NSKVOSwizzling
void
_NSKVOEnsureKeyWillNotify(id object, NSString *key) GS_ATTRIB_PRIVATE;

#endif

/* Implementation in NSKVOSupport.m for ObjC2 and NSKeyValueObserving
 * respectively
 */
@interface NSObject (NSKeyValueObservingPrivate)
- (Class) _underlyingClass;
- (void) _notifyObserversOfChangeForKey: (NSString *)key
                               oldValue: (id)oldValue
                               newValue: (id)newValue;
@end

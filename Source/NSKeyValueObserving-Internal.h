//******************************************************************************
//
// Copyright (c) Microsoft. All rights reserved.
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

#import <Foundation/Foundation.h>
#import "GSPThread.h"

#ifdef __cplusplus
extern "C" {
#endif

#define NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath)                               \
  do                                                                           \
    {                                                                          \
      [NSException                                                             \
	 raise:NSInvalidArgumentException                                      \
	format:@"-[%s %s] is not supported. Key path: %@",                     \
	       object_getClassName(self), sel_getName(_cmd), keyPath];         \
  } while (false)

@class _NSKVOKeypathObserver;

@interface _NSKVOKeyObserver : NSObject
- (instancetype)initWithObject:(id)object
	       keypathObserver:(_NSKVOKeypathObserver *)keypathObserver
			   key:(NSString *)key
		 restOfKeypath:(NSString *)restOfKeypath
	     affectedObservers:(NSArray *)affectedObservers;
@property (nonatomic, retain) _NSKVOKeypathObserver *keypathObserver;
@property (nonatomic, retain) _NSKVOKeyObserver	    *restOfKeypathObserver;
@property (nonatomic, retain) NSArray		    *dependentObservers;
@property (nonatomic, assign) id		     object;
@property (nonatomic, copy) NSString		    *key;
@property (nonatomic, copy) NSString		    *restOfKeypath;
@property (nonatomic, retain) NSArray		    *affectedObservers;
@property (nonatomic, assign) BOOL		     root;
@property (nonatomic, readonly) BOOL		     isRemoved;
@end

@interface _NSKVOKeypathObserver : NSObject
- (instancetype)initWithObject:(id)object
		      observer:(id)observer
		       keyPath:(NSString *)keypath
		       options:(NSKeyValueObservingOptions)options
		       context:(void *)context;
@property (nonatomic, assign) id			 object;
@property (nonatomic, assign) id			 observer;
@property (nonatomic, copy) NSString			*keypath;
@property (nonatomic, assign) NSKeyValueObservingOptions options;
@property (nonatomic, assign) void			*context;

@property (atomic, retain) NSMutableDictionary *pendingChange;
@end

@interface _NSKVOObservationInfo : NSObject
{
  NSMutableDictionary<NSString *, NSMutableArray<_NSKVOKeyObserver *> *>
			   *_keyObserverMap;
  NSInteger		    _dependencyDepth;
  NSMutableSet<NSString *> *_existingDependentKeys;
  gs_mutex_t		    _lock;
}
- (instancetype)init;
- (NSArray *)observersForKey:(NSString *)key;
- (void)addObserver:(_NSKVOKeyObserver *)observer;
@end

// From NSKVOSwizzling
void
_NSKVOEnsureKeyWillNotify(id object, NSString *key);

#ifdef __cplusplus
}
#endif

/* Implementation of NSObject for GNUStep
   Copyright (C) 1994, 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: August 1994
   
   This file is part of the GNU Objective C Class Library.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#include <objects/stdobjects.h>
#include <foundation/NSObject.h>
// #include <foundation/NSMethodSignature.h>
// #include <foundation/NSArchiver.h>
// #include <foundation/NSCoder.h>

@implementation NSObject

+ (void) initialize
{
  return;
}

+ (id) alloc
{
  return class_create_instance(self);
}

+ (id) allocWithZone: (NSZone*)z
{
  return [self alloc];		/* for now, until we get zones */
}

+ (id) new
{
  return [[self alloc] init];
}

- (id) copy
{
  return [self copyWithZone:0];
}

- (void) dealloc
{
  return object_dispose(self);
}

- free
{
  [self error:"Use `dealloc' instead of `free'."];
  return nil;
}

- (id) init
{
  return self;
}

- (id) mutableCopy
{
  return [self mutableCopyWithZone:0];
}

+ (Class) class
{
  return *(object_get_class(self));
}

+ (Class) superclass
{
  return *(object_get_super_class(self));
}

+ (BOOL) instancesRespondToSelector: (SEL)aSelector
{
  return class_get_instance_method(self, aSel)!=METHOD_NULL;
}

+ (BOOL) conformsToProtocol: (Protocol*)aProtocol
{
  int i;
  struct objc_protocol_list* proto_list;

  for (proto_list = isa->protocols;
       proto_list; proto_list = proto_list->next)
    {
      for (i=0; i < proto_list->count; i++)
      {
        if ([proto_list->list[i] conformsTo: aProtocol])
          return YES;
      }
    }

  if ([self superClass])
    return [[self superClass] conformsTo: aProtocol];
  else
    return NO;
}

+ (IMP) instanceMethodForSelector: (SEL)aSelector
{
  return method_get_imp(class_get_instance_method(self, aSel));
}
  
- (IMP) methodForSelector: (SEL)aSelector
{
  return (method_get_imp(object_is_instance(self)
                         ?class_get_instance_method(self->isa, aSel)
                         :class_get_class_method(self->isa, aSel)));
}

- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
  [self notImplemented:_cmd];
  return nil;
}

- (BOOL) isProxy
{
  return NO;
}

+ (NSString*) description
{
  return nil;
}

+ (void) poseAsClass: (Class)aClass
{
  return class_pose_as(self, aClassObject);
}

- (void) doesNotRecognizeSelector: (SEL)aSelector
{
  return [self error:"%s does not recognize %s",
                     object_get_class_name(self), sel_get_name(aSel)];
}

+ (void) cancelPreviousPerformRequestsWithTarget: (id)aTarget
   selector: (SEL)aSelector
   object: (id)anObject
{
  [self notImplemented:_cmd];
  return;
}

- (void) performSelector: (SEL)aSelector
   object: (id)anObject
   afterDelay: (NSTimeInterval)delay
{
  [self notImplemented:_cmd];
  return;
}

- (retval_t) forward:(SEL)aSel :(arglist_t)argFrame
{
  void *retFrame;
  NSMethodSignature *ms = [self methodSignatureForSelector:aSel];
  NSInvocation *inv = [NSInvocation invocationWithMethodSignature:ms
				    frame:argFrame];
  /* is this right? */
  retFrame = alloc([ms methodReturnLength]);
  [self forwardInvocation:inv];
  [inv getReturnValue:retFrame];
  /* where do ms and inv get free'd? */
  return retFrame;
}

- (void) forwardInvocation: (NSInvocation*)anInvocation
{
  [self doesNotRecognizeSelector:[anInvocation selector]];
  return;
}

- (id) awakeAfterUsingCoder: (NSCoder*)aDecoder
{
  return self;
}

- (Class) classForArchiver
{
  return [self classForCoder];
}

- (Class) classForCoder
{
  return [self class];
}

- (id) replacementObjectForArchiveer: (NSArchiver*)anArchiver
{
  return [self replacementObjectForCoder:anArchiver];
}

- (id) replacementObjectForCoder: (NSCoder*)anEncoder
{
  return self;
}

@end

NSObject *NSAllocateObject(Class aClass, unsigned extraBytes, NSZone *zone)
{
  
}

void NSDeallocateObject(NSObject *anObject)
{
  
}

NSObject *NSCopyObject(NSObject *anObject, unsigned extraBytes, NSZone *zone)
{
}

BOOL NSShouldRetainWithZone(NSObject *anObject, NSZone *requestedZone)
{
}

void NSIncrementExtraRefCount(id anObject)
{
}

BOOL NSDecrementExtraRefCountWasZero(id anObject)
{
}

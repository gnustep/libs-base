/* Implementation of Objective-C "collection of delegates" object
   Copyright (C) 1993,1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993
   
   This file is part of the GNU Objective-C Collection library.
   
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

#include <config.h>
#include <gnustep/base/DelegatePool.h>
#include <gnustep/base/NSString.h>

@implementation DelegatePool

+ (void) initialize
{
  return;
}

+ alloc
{
  return (id)class_create_instance(self);
}

+ new
{
  return [[self alloc] init];
}

/* This is the designated initializer for this class. */
- init
{
  _list = [[Array alloc] init];
  _send_behavior = SEND_TO_ALL;
  _last_message_had_receivers = NO;
  return self;
}

/* Archiving must mimic the above designated initializer */

- (void) encodeWithCoder: anEncoder
{
  [anEncoder encodeValueOfCType:@encode(unsigned char)
	     at:&_send_behavior
	     withName:@"DelegatePool Send Behavior"];
  [anEncoder encodeObject:_list
	     withName:@"DelegatePool Collection of Delegates"];
}

+ newWithCoder: aDecoder
{
  /* xxx Should be:
     DelegatePool *n = NSAllocateObject(self, 0, [aDecoder objectZone]); */
  DelegatePool *n = (id) NSAllocateObject(self, 0, NSDefaultMallocZone());
  [aDecoder decodeValueOfCType:@encode(unsigned char)
	    at:&(n->_send_behavior)
	    withName:NULL];
  [aDecoder decodeObjectAt:&(n->_list)
	    withName:NULL];
  return n;
}


- write: (TypedStream*)aStream
{
  objc_write_type(aStream, @encode(unsigned char), &_send_behavior);
  objc_write_object(aStream, _list);
  return self;
}

- read: (TypedStream*)aStream
{
  objc_write_type(aStream, @encode(unsigned char), &_send_behavior);
  objc_read_object(aStream, &_list);
  return self;
}

  
- (void) dealloc
{
  [_list release];
#if NeXT_runtime
  object_dispose((Object*)self);
#else
  NSDeallocateObject((NSObject*)self);
#endif
}


// MANIPULATING COLLECTION OF DELEGATES;

- (void) delegatePoolAddObject: anObject
{
  [_list addObject: anObject];
}

- (void) delegatePoolAddObjectIfAbsent: anObject
{
  [_list addObjectIfAbsent: anObject];
}

- (void) delegatePoolRemoveObject: anObject
{
  [_list removeObject:anObject];
}

- (BOOL) delegatePoolIncludesObject: anObject
{
  return [_list containsObject:anObject];
}

- delegatePoolCollection
{
  return _list;
}

- (unsigned char) delegatePoolSendBehavior
{
  return _send_behavior;
}

- (void) delegatePoolSetSendBehavior: (unsigned char)b
{
  _send_behavior = b;
}

- (BOOL) delegatePoolLastMessageHadReceivers
{
  return _last_message_had_receivers;
}

// FOR PASSING ALL OTHER MESSAGES TO DELEGATES;

- forward: (SEL)aSel :(arglist_t)argFrame
{
  void *ret = 0;
  id delegate;
  
  _last_message_had_receivers = NO;
  switch (_send_behavior) 
    {
    case SEND_TO_ALL:
      FOR_ARRAY(_list, delegate)
	{
	  if ([delegate respondsTo:aSel]) 
	    {
	      ret = [delegate performv:aSel :argFrame];
	      _last_message_had_receivers = YES;
	    }
	}
      END_FOR_ARRAY (_list);
      break;
      
    case SEND_TO_FIRST_RESPONDER:
      FOR_ARRAY(_list, delegate)
	{
	  if ([delegate respondsTo:aSel]) 
	    {
	      _last_message_had_receivers = YES;
	      return [delegate performv:aSel :argFrame];
	    }
	}
      END_FOR_ARRAY (_list);
      break;
      
    case SEND_UNTIL_YES:
      FOR_ARRAY(_list, delegate)
	{
	  if ([delegate respondsTo:aSel]) 
	    {
	      _last_message_had_receivers = YES;
	      if ((ret = [delegate performv:aSel :argFrame]))
		return ret;
	    }
	}
      END_FOR_ARRAY (_list);
      break;
      
    case SEND_UNTIL_NO:
      FOR_ARRAY(_list, delegate)
	{
	  if ([delegate respondsTo:aSel]) 
	    {
	      _last_message_had_receivers = YES;
	      if (!(ret = [delegate performv:aSel :argFrame]))
		return ret;
	    }
	}
      END_FOR_ARRAY (_list);
      break;
    }
  return ret;
}

@end

/* Implementation of Objective-C "collection of delegates" object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
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

#include <objects/DelegatePool.h>

@implementation DelegatePool

+ initialize
{
  return self;
}

+ alloc
{
  return (id)class_create_instance(self);
}

+ new
{
  return [[self alloc] init];
}

- init
{
  _list = [[Array alloc] init];
  _send_behavior = SEND_TO_ALL;
  return self;
}

/* Archiving must mimic the above designated initializer */

- (void) encodeWithCoder: (Coder*)anEncoder
{
  [anEncoder encodeValueOfSimpleType:@encode(unsigned char)
	     at:&_send_behavior
	     withName:"DelegatePool Send Behavior"];
  [anEncoder encodeObject:_list
	     withName:"DelegatePool Collection of Delegates"];
}

+ newWithCoder: (Coder*)aDecoder
{
  DelegatePool *n = class_create_instance(self);
  [aDecoder decodeValueOfSimpleType:@encode(unsigned char)
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

  
- free
{
  [_list free];
#if NeXT_runtime
  return (id) object_dispose((Object*)self);
#else
  return (id) object_dispose(self);
#endif
}


// MANIPULATING COLLECTION OF DELEGATES;

- delegatePoolAddObject: anObject
{
  [_list addObject: anObject];
  return self;
}

- delegatePoolAddObjectIfAbsent: anObject
{
  [_list addObjectIfAbsent: anObject];
  return self;
}

- delegatePoolRemoveObject: anObject
{
  return [_list removeObject:anObject];
}

- (BOOL) delegatePoolIncludesObject: anObject
{
  return [_list includesObject:anObject];
}

- delegatePoolCollection
{
  return _list;
}

- (unsigned char) delegatePoolSendBehavior
{
  return _send_behavior;
}

- delegatePoolSetSendBehavior: (unsigned char)b
{
  _send_behavior = b;
  return self;
}


// FOR PASSING ALL OTHER MESSAGES TO DELEGATES;

- forward: (SEL)aSel :(arglist_t)argFrame
{
  void *ret = 0;
  elt delegate;
  
  switch (_send_behavior) 
    {
    case SEND_TO_ALL:
      FOR_ARRAY(_list, delegate)
	{
	  if ([delegate.id_u respondsTo:aSel]) 
	    ret = [delegate.id_u performv:aSel :argFrame];
	}
      FOR_ARRAY_END;
      break;
      
    case SEND_TO_FIRST_RESPONDER:
      FOR_ARRAY(_list, delegate)
	{
	  if ([delegate.id_u respondsTo:aSel]) 
	    return [delegate.id_u performv:aSel :argFrame];
	}
      FOR_ARRAY_END;
      break;
      
    case SEND_UNTIL_YES:
      FOR_ARRAY(_list, delegate)
	{
	  if ([delegate.id_u respondsTo:aSel]) 
	    if ((ret = [delegate.id_u performv:aSel :argFrame]))
	      return ret;
	}
      FOR_ARRAY_END;
      break;
      
    case SEND_UNTIL_NO:
      FOR_ARRAY(_list, delegate)
	{
	  if ([delegate.id_u respondsTo:aSel]) 
	    if (!(ret = [delegate.id_u performv:aSel :argFrame]))
	      return ret;
	}
      FOR_ARRAY_END;
      break;
    }
  return ret;
}

@end

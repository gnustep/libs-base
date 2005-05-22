/* Interface for NSPortCoder object for distributed objects
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: June 2000

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
   */

#ifndef __NSPortCoder_h
#define __NSPortCoder_h

#include <Foundation/NSCoder.h>

@class NSMutableArray;
@class NSMutableDictionary;
@class NSConnection;
@class NSPort;

/**
 * This class is an [NSCoder] implementation specialized for sending objects
 * over network connections for immediate use (as opposed to the archivers
 * which persist objects for reconstitution after an indefinite term).  It is
 * used to help implement the distributed objects framework by the
 * [NSConnection] class.  Even for highly specialized applications, you
 * probably do not need to use this class directly.
 */
//FIXME: the above is what Apple's docs say, but looking at the code the
// NSConnection is actually created by this class rather than the other way
// around, so maybe the docs should be changed..
@interface NSPortCoder : NSCoder
{
@private
  NSMutableArray	*_comp;
  NSConnection		*_conn;
  BOOL			_is_by_copy;
  BOOL			_is_by_ref;
// Encoding
  BOOL			_encodingRoot;
  BOOL			_initialPass;
  id			_dst;		/* Serialization destination.	*/
  IMP			_eObjImp;	/* Method to encode an id.	*/
  IMP			_eValImp;	/* Method to encode others.	*/
#ifndef	_IN_PORT_CODER_M
#define	GSIMapTable	void*
#endif
  GSIMapTable		_clsMap;	/* Class cross references.	*/
  GSIMapTable		_cIdMap;	/* Conditionally coded.		*/
  GSIMapTable		_uIdMap;	/* Unconditionally coded.	*/
  GSIMapTable		_ptrMap;	/* Constant pointers.		*/
#ifndef	_IN_PORT_CODER_M
#undef	GSIMapTable
#endif
  unsigned		_xRefC;		/* Counter for cross-reference.	*/
  unsigned		_xRefO;		/* Counter for cross-reference.	*/
  unsigned		_xRefP;		/* Counter for cross-reference.	*/
// Decoding
  id			_src;		/* Deserialization source.	*/
  IMP			_dDesImp;	/* Method to deserialize with.	*/
  void			(*_dTagImp)(id,SEL,unsigned char*,unsigned*,unsigned*);
  IMP			_dValImp;	/* Method to decode data with.	*/
#ifndef	_IN_PORT_CODER_M
#define	GSIArray	void*
#endif
  GSIArray		_clsAry;	/* Class crossreference map.	*/
  GSIArray		_objAry;	/* Object crossreference map.	*/
  GSIArray		_ptrAry;	/* Pointer crossreference map.	*/
#ifndef	_IN_PORT_CODER_M
#undef	GSIArray
#endif
  NSMutableDictionary	*_cInfo;	/* Class version information.	*/
  unsigned		_cursor;	/* Position in data buffer.	*/
  unsigned		_version;	/* Version of archiver used.	*/
  NSZone		*_zone;		/* Zone for allocating objs.	*/
}

/**
 * Create a new instance for communications over send and recv, and send an
 * initial message through send as specified by comp.
 */
+ (NSPortCoder*) portCoderWithReceivePort: (NSPort*)recv
				 sendPort: (NSPort*)send
			       components: (NSArray*)comp;

/**
 * Initialize a new instance for communications over send and recv, and send an
 * initial message through send as specified by comp.
 */
- (id) initWithReceivePort: (NSPort*)recv
		  sendPort: (NSPort*)send
		components: (NSArray*)comp;

/**
 * Returns the <code>NSConnection</code> using this instance.
 */
- (NSConnection*) connection;

/**
 * Return port object previously encoded by this instance.  Mainly for use
 * by the ports themselves.
 */
- (NSPort*) decodePortObject;

/**
 * Processes and acts upon the initial message the receiver was initialized
 * with..
 */
- (void) dispatch;

/**
 * Encodes aPort so it can be sent to the receiving side of the connection.
 * Mainly for use by the ports themselves.
 */
- (void) encodePortObject: (NSPort*)aPort;

/**
 * Returns YES if receiver is in the process of encoding objects by copying
 * them (rather than substituting a proxy).  This method is mainly needed
 * internally and by subclasses.
 */
- (BOOL) isBycopy;

/**
 * Returns YES if receiver will substitute a proxy when encoding objects
 * rather than by copying them.  This method is mainly needed
 * internally and by subclasses.
 */
- (BOOL) isByref;

@end

@interface	NSPortCoder (Private)
- (NSMutableArray*) _components;
@end


#endif /* __NSPortCoder_h */

/** Interface for NSKeyedArchiver for GNUStep
   Copyright (C) 2004 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: January 2004
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   AutogsdocSource: NSKeyedArchiver.m
   AutogsdocSource: NSKeyedUnarchiver.m

   */ 

#ifndef __NSKeyedArchiver_h_GNUSTEP_BASE_INCLUDE
#define __NSKeyedArchiver_h_GNUSTEP_BASE_INCLUDE

#ifndef	STRICT_OPENSTEP

#include <Foundation/NSCoder.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSPropertyList.h>

@class NSMutableDictionary, NSMutableData, NSData, NSString;

/**
 * Keyed archiving class, <strong>NOT YET IMPLEMENTED</strong>
 */
@interface NSKeyedArchiver : NSCoder
{
@private
  NSMutableData	*_data;		/* Data to write into.		*/
  id		_delegate;	/* Delegate controls operation.	*/
  NSMapTable	*_clsMap;	/* Map classes to names.	*/
#ifndef	_IN_NSKEYEDARCHIVER_M
#define	GSIMapTable	void*
#endif
  GSIMapTable	_cIdMap;	/* Conditionally coded.		*/
  GSIMapTable	_uIdMap;	/* Unconditionally coded.	*/
  GSIMapTable	_repMap;	/* Mappings for objects.	*/
#ifndef	_IN_NSKEYEDARCHIVER_M
#undef	GSIMapTable
#endif
  unsigned	_keyNum;	/* Counter for keys in object.	*/
  NSMutableDictionary	*_enc;	/* Object being encoded.	*/
  NSMutableArray	*_obj;	/* Array of objects.		*/
  NSPropertyListFormat	_format;
}

/**
 * Encodes anObject and returns the resulting data object.
 */
+ (NSData*) archivedDataWithRootObject: (id)anObject;

/**
 * Encodes anObject and writes the resulting data ti aPath.
 */
+ (BOOL) archiveRootObject: (id)anObject toFile: (NSString*)aPath;

/**
 * Returns the class name with which the NSKeyedArchiver class will encode
 * instances of aClass, or nil if no name mapping has been set using the
 * +setClassName:forClass: method.
 */
+ (NSString*) classNameForClass: (Class)aClass;

/**
 * Sets the class name with which the NSKeyedArchiver class will encode
 * instances of aClass.  This mapping is used only if no class name
 * mapping has been set for the individual instance of NSKeyedArchiver
 * being used.<br />
 * The value of aString must be the name of an existing class.<br />
 * If the value of aString is nil, any mapping for aClass is removed.
 */
+ (void) setClassName: (NSString*)aString forClass: (Class)aClass;

/**
 * Returns any mapping for the name of aClass which was previously set
 * for the receiver using the -setClassName:forClass: method.<br />
 * Returns nil if no such mapping exists, even if one has been set
 * using the class method +setClassName:forClass: 
 */
- (NSString*) classNameForClass: (Class)aClass;

/**
 * Returns the delegate set for the receiver, or nil of none is set.
 */
- (id) delegate;

- (void) encodeBool: (BOOL)aBool forKey: (NSString*)aKey;
- (void) encodeBytes: (const uint8_t*)aPointer length: (unsigned)length forKey: (NSString*)aKey;
- (void) encodeConditionalObject: (id)anObject forKey: (NSString*)aKey;
- (void) encodeDouble: (double)aDouble forKey: (NSString*)aKey;
- (void) encodeFloat: (float)aFloat forKey: (NSString*)aKey;
- (void) encodeInt: (int)anInteger forKey: (NSString*)aKey;
- (void) encodeInt32: (int32_t)anInteger forKey: (NSString*)aKey;
- (void) encodeInt64: (int64_t)anInteger forKey: (NSString*)aKey;
- (void) encodeObject: (id)anObject forKey: (NSString*)aKey;

/**
 * Ends the encoding process and causes the encoded archive to be placed
 * in the mutable data object supplied when the receiver was initialised.<br />
 * This method must be called at the end of encoding, and nothing may be
 * encoded after this method is called.
 */
- (void) finishEncoding;

/**
 * Initialise the receiver to encode an archive into the supplied
 * data object.
 */
- (id) initForWritingWithMutableData: (NSMutableData*)data;

/**
 * Returns the output format of the archived data ... this should default
 * to the MacOS-X binary format, but we don't support that yet, so the
 * -setOutputFormat: method should be used to set a supported format.
 */
- (NSPropertyListFormat) outputFormat;

/**
 * Sets the name with which instances of aClass are encoded.<br />
 * The value of aString must be the anme of an existing clas.
 */
- (void) setClassName: (NSString*)aString forClass: (Class)aClass;

/**
 * Sets the receivers delegate.  The delegate should conform to the
 * NSObject(NSKeyedArchiverDelegate) informal protocol.<br />
 * NB. the delegate is not retained, so you must ensure that it is not
 * deallocated before the archiver has finished with it.
 */
- (void) setDelegate: (id)anObject;

/**
 * Specifies the output format of the archived data ... this should default
 * to the MacOS-X binary format, but we don't support that yet, so the
 * -setOutputFormat: method should be used to set a supported format.
 */
- (void) setOutputFormat: (NSPropertyListFormat)format;

@end



/**
 * Keyed unarchiving class, <strong>NOT YET IMPLEMENTED</strong>
 */
@interface NSKeyedUnarchiver : NSCoder
{
@private
  NSDictionary	*_archive;
  id		_delegate;	/* Delegate controls operation.	*/
  NSMapTable	*_clsMap;	/* Map classes to names.	*/
  NSArray	*_objects;	/* All encoded objects.		*/
  NSDictionary	*_keyMap;	/* Local object name table.	*/
  unsigned	_cursor;	/* Position in object.		*/
  NSString	*_archiverClass;
  NSString	*_version;
#ifndef	_IN_NSKEYEDUNARCHIVER_M
#define	GSIArray	void*
#endif
  GSIArray		_objMap; /* Decoded objects.		*/
#ifndef	_IN_NSKEYEDUNARCHIVER_M
#undef	GSUnarchiverArray
#endif
  NSZone	*_zone;		/* Zone for allocating objs.	*/
}

+ (Class) classForClassName: (NSString*)aString;
+ (void) setClass: (Class)aClass forClassName: (NSString*)aString;
+ (id) unarchiveObjectWithData: (NSData*)data;
+ (id) unarchiveObjectWithFile: (NSString*)aPath;

- (Class) classForClassName: (NSString*)aString;
- (BOOL) containsValueForKey: (NSString*)aKey;
- (BOOL) decodeBoolForKey: (NSString*)aKey;
- (const uint8_t*) decodeBytesForKey: (NSString*)aKey
		      returnedLength: (unsigned*)length;
- (double) decodeDoubleForKey: (NSString*)aKey;
- (float) decodeFloatForKey: (NSString*)aKey;
- (int) decodeIntForKey: (NSString*)aKey;
- (int32_t) decodeInt32ForKey: (NSString*)aKey;
- (int64_t) decodeInt64ForKey: (NSString*)aKey;
- (id) decodeObjectForKey: (NSString*)aKey;
/**
 * returns the delegate of the unarchiver.
 */
- (id) delegate;
- (void) finishDecoding;
- (id) initForReadingWithData: (NSData*)data;
- (void) setClass: (Class)aClass forClassName: (NSString*)aString;
/**
 * Sets the receivers delegate.  The delegate should conform to the
 * NSObject(NSKeyedUnarchiverDelegate) informal protocol.<br />
 * NB. the delegate is not retained, so you must ensure that it is not
 * deallocated before the unarchiver has finished with it.
 */
- (void) setDelegate: (id)delegate;

@end


/* Exceptions */
GS_EXPORT NSString * const NSInvalidArchiveOperationException;
GS_EXPORT NSString * const NSInvalidUnarchiveOperationException;


/**
 * Informal protocol implemented by delegates of [NSKeyedArchiver]
 */
@interface NSObject (NSKeyedArchiverDelegate)

/**
 * Sent when encoding of anObject has completed <em>except</em> in the case
 * of conditional encoding.
 */
- (void) archiver: (NSKeyedArchiver*)anArchiver didEncodeObject: (id)anObject;

/**
 * Sent when anObject is about to be encoded (or conditionally encoded)
 * and provides the receiver with an opportunity to change the actual
 * object stored into the archive by returning a different value (otherwise
 * it should return anObject).<br />
 * The method is not called for encoding of nil or for encoding of any
 * object for which has already been called.<br />
 * The method is called <em>after</em> the -replacementObjectForKeyedArchiver:
 * method.
 */
- (id) archiver: (NSKeyedArchiver*)anArchiver willEncodeObject: (id)anObject;

/**
 * Sent when the encoding process is complete.
 */
- (void) archiverDidFinish: (NSKeyedArchiver*)anArchiver;

/**
 * Sent when the encoding process is about to finish.
 */
- (void) archiverWillFinish: (NSKeyedArchiver*)anArchiver;

/**
 * Sent whenever object replacement occurs during encoding, either by the
 * -replacementObjectForKeyedArchiver: method or because the delegate has
 * returned a changed value using the -archiver:willEncodeObject: method.
 */
- (void) archiver: (NSKeyedArchiver*)anArchiver
willReplaceObject: (id)anObject
       withObject: (id)newObject;

@end



/**
 * Informal protocol implemented by delegates of [NSKeyedUnarchiver]
 */
@interface NSObject (NSKeyedUnarchiverDelegate) 

/**
 * Sent if the named class is not available during decoding.<br />
 * The value of aName is the class name being decoded (after any name mapping
 * has been applied).<br />
 * The classNames arraay contains the original name of the class encoded
 * in the archive, and is followed by eqach of its superclasses in turn.<br />
 * The delegate may either return a class object for the unarchiver to use
 * to continue decoding, or may return nil to abort the decoding process.
 */
- (Class) unarchiver: (NSKeyedUnarchiver*)anUnarchiver
  cannotDecodeObjectOfClassName: (NSString*)aName
  originalClasses: (NSArray*)classNames;

/**
 * Sent when anObject is decoded.  The receiver may return either anObject
 * or some other object (including nil).  If a value other than anObject is
 * returned, it is used to replace anObject.
 */
- (id) unarchiver: (NSKeyedUnarchiver*)anUnarchiver
  didDecodeObject: (id)anObject;

/**
 * Sent when unarchiving is about to complete.
 */
- (void) unarchiverDidFinish: (NSKeyedUnarchiver*)anUnarchiver;

/**
 * Sent when unarchiving has been completed.
 */
- (void) unarchiverWillFinish: (NSKeyedUnarchiver*)anUnarchiver;

/**
 * Sent whenever object replacement occurs during decoding, eg by the
 * -replacementObjectForKeyedArchiver: method.
 */
- (void) unarchiver: (NSKeyedUnarchiver*)anUnarchiver
  willReplaceObject: (id)anObject
	 withObject: (id)newObject;

@end



/**
 * Methods by which a class may control its archiving by the NSKeyedArchiver
 */
@interface NSObject (NSKeyedArchiverObjectSubstitution) 

/**
 * This message is sent to objects being encoded, to allow them to choose
 * to be encoded a different class.  If this returns nil it is treated as
 * if it returned the class of the object.<br />
 * After this method is applied, any class name mapping set in the archiver
 * is applied to its result.<br />
 * The default implementation returns the result of the -classForArchiver
 * method.
 */
- (Class) classForKeyedArchiver;

/**
 * This message is sent to objects being encoded, to allow them to choose
 * to be encoded a different object by returning the alternative object.<br />
 * The default implementation returns the result of calling
 * the -replacementObjectForArchiver: method with a nil argument.<br />
 * This is called only if no mapping has been set up in the archiver already.
 */
- (id) replacementObjectForKeyedArchiver: (NSKeyedArchiver*)archiver;

@end

@interface NSObject (NSKeyedUnarchiverObjectSubstitution) 

/**
 * Sent during unarchiving to permit classes to substitute a different
 * class for decoded instances of themselves.<br />
 * Default implementation returns the receiver.<br />
 * Overrides the mappings set up within the receiver.
 */
+ (Class) classForKeyedUnarchiver;

@end

@interface NSCoder (NSGeometryKeyedCoding)
/**
 * Encodes an NSPoint object.
 */
- (void) encodePoint: (NSPoint)aPoint forKey: (NSString*)aKey;

/**
 * Encodes an NSRect object.
 */
- (void) encodeRect: (NSRect)aRect forKey: (NSString*)aKey;

/**
 * Encodes an NSSize object.
 */
- (void) encodeSize: (NSSize)aSize forKey: (NSString*)aKey;

/**
 * Decodes an NSPoint object.
 */
- (NSPoint) decodePointForKey: (NSString*)aKey;

/**
 * Decodes an NSRect object.
 */
- (NSRect) decodeRectForKey: (NSString*)aKey;

/**
 * Decodes an NSSize object.
 */
- (NSSize) decodeSizeForKey: (NSString*)aKey;
@end

#endif	/* STRICT_OPENSTEP */
#endif	/* __NSKeyedArchiver_h_GNUSTEP_BASE_INCLUDE*/

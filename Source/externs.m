/* All of the external data
   Copyright (C) 1997 Free Software Foundation, Inc.
   
   Written by:  Scott Christley <scottc@net-community.com>
   Date: August 1997
   
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
   */ 

#include <config.h>
#include <Foundation/NSString.h>


#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSMapTable.h>
#include "NSCallBacks.h"
#include <Foundation/NSHashTable.h>

/* Global lock to be used by classes when operating on any global
   data that invoke other methods which also access global; thus,
   creating the potential for deadlock. */
@class	NSRecursiveLock;
NSRecursiveLock *gnustep_global_lock = nil;

/*
 * Connection Notification Strings.
 */
NSString *NSConnectionDidDieNotification;
NSString *NSConnectionDidInitializeNotification;

/*
 * NSThread Notifications
 */
NSString *NSWillBecomeMultiThreadedNotification;
NSString *NSThreadWillExitNotification;

/*
 * Port Notifications
 */
NSString *PortBecameInvalidNotification;
NSString *InPortClientBecameInvalidNotification;
NSString *InPortAcceptedClientNotification;

NSString *NSPortDidBecomeInvalidNotification;


/* RunLoop modes */
NSString *NSDefaultRunLoopMode;
NSString *NSConnectionReplyMode;


/* Exceptions */
NSString *NSCharacterConversionException;
NSString *NSFailedAuthenticationException;
NSString *NSGenericException;
NSString *NSInconsistentArchiveException;
NSString *NSInternalInconsistencyException;
NSString *NSInvalidArgumentException;
NSString *NSMallocException;
NSString *NSPortTimeoutException;
NSString *NSRangeException;

/* Exception handler */
NSUncaughtExceptionHandler *_NSUncaughtExceptionHandler;

/* NSBundle */
NSString *NSBundleDidLoadNotification;
NSString *NSShowNonLocalizedStrings;
NSString *NSLoadedClasses;

/* Stream */
NSString *StreamException;

/*
 * File attributes names
 */

/* File Attributes */

NSString *NSFileDeviceIdentifier;
NSString *NSFileGroupOwnerAccountName;
NSString *NSFileGroupOwnerAccountNumber;
NSString *NSFileModificationDate;
NSString *NSFileOwnerAccountName;
NSString *NSFileOwnerAccountNumber;
NSString *NSFilePosixPermissions;
NSString *NSFileReferenceCount;
NSString *NSFileSize;
NSString *NSFileSystemFileNumber;
NSString *NSFileSystemNumber;
NSString *NSFileType;

/* File Types */

NSString *NSFileTypeDirectory;
NSString *NSFileTypeRegular;
NSString *NSFileTypeSymbolicLink;
NSString *NSFileTypeSocket;
NSString *NSFileTypeFifo;
NSString *NSFileTypeCharacterSpecial;
NSString *NSFileTypeBlockSpecial;
NSString *NSFileTypeUnknown;

/* FileSystem Attributes */

NSString *NSFileSystemSize;
NSString *NSFileSystemFreeSize;
NSString *NSFileSystemNodes;
NSString *NSFileSystemFreeNodes;

/* Standard domains */
NSString *NSArgumentDomain;
NSString *NSGlobalDomain;
NSString *NSRegistrationDomain;

/* Public notification */
NSString *NSUserDefaultsDidChangeNotification;

/* Keys for language-dependent information */
NSString *NSWeekDayNameArray;
NSString *NSShortWeekDayNameArray;
NSString *NSMonthNameArray;
NSString *NSShortMonthNameArray;
NSString *NSTimeFormatString;
NSString *NSDateFormatString;
NSString *NSTimeDateFormatString;
NSString *NSShortTimeDateFormatString;
NSString *NSCurrencySymbol;
NSString *NSDecimalSeparator;
NSString *NSThousandsSeparator;
NSString *NSInternationalCurrencyString;
NSString *NSCurrencyString;
NSString *NSDecimalDigits;
NSString *NSAMPMDesignation;

NSString *NSHourNameDesignations;
NSString *NSYearMonthWeekDesignations;
NSString *NSEarlierTimeDesignations;
NSString *NSLaterTimeDesignations;
NSString *NSThisDayDesignations;
NSString *NSNextDayDesignations;
NSString *NSNextNextDayDesignations;
NSString *NSPriorDayDesignations;
NSString *NSDateTimeOrdering;

/*
 * Keys for the NSDictionary returned by [NSConnection -statistics]
 */
/* These in OPENSTEP 4.2 */
NSString *NSConnectionRepliesReceived;
NSString *NSConnectionRepliesSent;
NSString *NSConnectionRequestsReceived;
NSString *NSConnectionRequestsSent;
/* These Are GNUstep extras */
NSString *NSConnectionLocalCount;
NSString *NSConnectionProxyCount;

/*
 *	Setup function called when NSObject is initialised.
 *	We make all the constant strings not be NXConstantString so they can
 *	cache their hash values and be used much more efficiently as keys in
 *	dictionaries etc.
 */
void
GSBuildStrings()
{
  static BOOL	beenHere = NO;

  if (beenHere == NO)
    {
      beenHere = YES;
      InPortAcceptedClientNotification
	= [[NSString alloc] initWithCString:
	"InPortAcceptedClientNotification"];
      InPortClientBecameInvalidNotification
	= [[NSString alloc] initWithCString:
	"InPortClientBecameInvalidNotification"];
      NSAMPMDesignation
	= [[NSString alloc] initWithCString: "NSAMPMDesignation"];
      NSArgumentDomain
	= [[NSString alloc] initWithCString: "NSArgumentDomain"];
      NSBundleDidLoadNotification
	= [[NSString alloc] initWithCString: "NSBundleDidLoadNotification"];
      NSCharacterConversionException
	= [[NSString alloc] initWithCString: "NSCharacterConversionException"];
      NSConnectionDidDieNotification
	= [[NSString alloc] initWithCString: "NSConnectionDidDieNotification"];
      NSConnectionDidInitializeNotification
	= [[NSString alloc] initWithCString:
	"NSConnectionDidInitializeNotification"];
      NSConnectionLocalCount
	= [[NSString alloc] initWithCString: "NSConnectionLocalCount"];
      NSConnectionProxyCount
	= [[NSString alloc] initWithCString: "NSConnectionProxyCount"];
      NSConnectionRepliesReceived
	= [[NSString alloc] initWithCString: "NSConnectionRepliesReceived"];
      NSConnectionRepliesSent
	= [[NSString alloc] initWithCString: "NSConnectionRepliesSent"];
      NSConnectionReplyMode
	= [[NSString alloc] initWithCString: "NSConnectionReplyMode"];
      NSConnectionRequestsReceived
	= [[NSString alloc] initWithCString: "NSConnectionRequestsReceived"];
      NSConnectionRequestsSent
	= [[NSString alloc] initWithCString: "NSConnectionRequestsSent"];
      NSCurrencyString
	= [[NSString alloc] initWithCString: "NSCurrencyString"];
      NSCurrencySymbol
	= [[NSString alloc] initWithCString: "NSCurrencySymbol"];
      NSDateFormatString
	= [[NSString alloc] initWithCString: "NSDateFormatString"];
      NSDateTimeOrdering
	= [[NSString alloc] initWithCString: "NSDateTimeOrdering"];
      NSDecimalDigits
	= [[NSString alloc] initWithCString: "NSDecimalDigits"];
      NSDecimalSeparator
	= [[NSString alloc] initWithCString: "NSDecimalSeparator"];
      NSDefaultRunLoopMode
	= [[NSString alloc] initWithCString: "NSDefaultRunLoopMode"];
      NSEarlierTimeDesignations
	= [[NSString alloc] initWithCString: "NSEarlierTimeDesignations"];
      NSFailedAuthenticationException
	= [[NSString alloc] initWithCString: "NSFailedAuthenticationException"];
      NSFileDeviceIdentifier
	= [[NSString alloc] initWithCString: "NSFileDeviceIdentifier"];
      NSFileGroupOwnerAccountName
	= [[NSString alloc] initWithCString: "NSFileGroupOwnerAccountName"];
      NSFileGroupOwnerAccountNumber
	= [[NSString alloc] initWithCString: "NSFileGroupOwnerAccountNumber"];
      NSFileModificationDate
	= [[NSString alloc] initWithCString: "NSFileModificationDate"];
      NSFileOwnerAccountName
	= [[NSString alloc] initWithCString: "NSFileOwnerAccountName"];
      NSFileOwnerAccountNumber
	= [[NSString alloc] initWithCString: "NSFileOwnerAccountNumber"];
      NSFilePosixPermissions
	= [[NSString alloc] initWithCString: "NSFilePosixPermissions"];
      NSFileReferenceCount
	= [[NSString alloc] initWithCString: "NSFileReferenceCount"];
      NSFileSize
	= [[NSString alloc] initWithCString: "NSFileSize"];
      NSFileSystemFileNumber
	= [[NSString alloc] initWithCString: "NSFileSystemFileNumber"];
      NSFileSystemFreeNodes
	= [[NSString alloc] initWithCString: "NSFileSystemFreeNodes"];
      NSFileSystemFreeSize
	= [[NSString alloc] initWithCString: "NSFileSystemFreeSize"];
      NSFileSystemNodes
	= [[NSString alloc] initWithCString: "NSFileSystemNodes"];
      NSFileSystemNumber
	= [[NSString alloc] initWithCString: "NSFileSystemNumber"];
      NSFileSystemSize
	= [[NSString alloc] initWithCString: "NSFileSystemSize"];
      NSFileType
	= [[NSString alloc] initWithCString: "NSFileType"];
      NSFileTypeBlockSpecial
	= [[NSString alloc] initWithCString: "NSFileTypeBlockSpecial"];
      NSFileTypeCharacterSpecial
	= [[NSString alloc] initWithCString: "NSFileTypeCharacterSpecial"];
      NSFileTypeDirectory
	= [[NSString alloc] initWithCString: "NSFileTypeDirectory"];
      NSFileTypeFifo
	= [[NSString alloc] initWithCString: "NSFileTypeFifo"];
      NSFileTypeRegular
	= [[NSString alloc] initWithCString: "NSFileTypeRegular"];
      NSFileTypeSocket
	= [[NSString alloc] initWithCString: "NSFileTypeSocket"];
      NSFileTypeSymbolicLink
	= [[NSString alloc] initWithCString: "NSFileTypeSymbolicLink"];
      NSFileTypeUnknown
	= [[NSString alloc] initWithCString: "NSFileTypeUnknown"];
      NSGenericException
	= [[NSString alloc] initWithCString: "NSGenericException"];
      NSGlobalDomain
	= [[NSString alloc] initWithCString: "NSGlobalDomain"];
      NSHourNameDesignations
	= [[NSString alloc] initWithCString: "NSHourNameDesignations"];
      NSInconsistentArchiveException
	= [[NSString alloc] initWithCString: "NSInconsistentArchiveException"];
      NSInternalInconsistencyException
	= [[NSString alloc] initWithCString:
	"NSInternalInconsistencyException"];
      NSInternationalCurrencyString
	= [[NSString alloc] initWithCString: "NSInternationalCurrencyString"];
      NSInvalidArgumentException
	= [[NSString alloc] initWithCString: "NSInvalidArgumentException"];
      NSLaterTimeDesignations
	= [[NSString alloc] initWithCString: "NSLaterTimeDesignations"];
      NSLoadedClasses
	= [[NSString alloc] initWithCString: "NSLoadedClasses"];
      NSMallocException
	= [[NSString alloc] initWithCString: "NSMallocException"];
      NSMonthNameArray
	= [[NSString alloc] initWithCString: "NSMonthNameArray"];
      NSNextDayDesignations
	= [[NSString alloc] initWithCString: "NSNextDayDesignations"];
      NSNextNextDayDesignations
	= [[NSString alloc] initWithCString: "NSNextNextDayDesignations"];
      NSPortDidBecomeInvalidNotification
	= [[NSString alloc] initWithCString:
	"NSPortDidBecomeInvalidNotification"];
      NSPortTimeoutException
	= [[NSString alloc] initWithCString: "NSPortTimeoutException"];
      NSPriorDayDesignations
	= [[NSString alloc] initWithCString: "NSPriorDayDesignations"];
      NSRangeException
	= [[NSString alloc] initWithCString: "NSRangeException"];
      NSRegistrationDomain
	= [[NSString alloc] initWithCString: "NSRegistrationDomain"];
      NSShortMonthNameArray
	= [[NSString alloc] initWithCString: "NSShortMonthNameArray"];
      NSShortTimeDateFormatString
	= [[NSString alloc] initWithCString: "NSShortTimeDateFormatString"];
      NSShortWeekDayNameArray
	= [[NSString alloc] initWithCString: "NSShortWeekDayNameArray"];
      NSShowNonLocalizedStrings
	= [[NSString alloc] initWithCString: "NSShowNonLocalizedStrings"];
      NSThisDayDesignations
	= [[NSString alloc] initWithCString: "NSThisDayDesignations"];
      NSThousandsSeparator
	= [[NSString alloc] initWithCString: "NSThousandsSeparator"];
      NSThreadWillExitNotification
	= [[NSString alloc] initWithCString: "NSThreadWillExitNotification"];
      NSTimeDateFormatString
	= [[NSString alloc] initWithCString: "NSTimeDateFormatString"];
      NSTimeFormatString
	= [[NSString alloc] initWithCString: "NSTimeFormatString"];
      NSUserDefaultsDidChangeNotification
	= [[NSString alloc] initWithCString:
	"NSUserDefaultsDidChangeNotification"];
      NSWeekDayNameArray
	= [[NSString alloc] initWithCString: "NSWeekDayNameArray"];
      NSWillBecomeMultiThreadedNotification
	= [[NSString alloc] initWithCString:
	"NSWillBecomeMultiThreadedNotification"];
      NSYearMonthWeekDesignations
	= [[NSString alloc] initWithCString: "NSYearMonthWeekDesignations"];
      PortBecameInvalidNotification
	= [[NSString alloc] initWithCString: "PortBecameInvalidNotification"];
      StreamException
	= [[NSString alloc] initWithCString: "StreamException"];
    }
}



/* Standard MapTable callbacks */

const NSMapTableKeyCallBacks NSIntMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_int_hash,
  (NSMT_is_equal_func_t) _NS_int_is_equal,
  (NSMT_retain_func_t) _NS_int_retain,
  (NSMT_release_func_t) _NS_int_release,
  (NSMT_describe_func_t) _NS_int_describe,
  0
};

const NSMapTableKeyCallBacks NSNonOwnedPointerMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_non_owned_void_p_hash,
  (NSMT_is_equal_func_t) _NS_non_owned_void_p_is_equal,
  (NSMT_retain_func_t) _NS_non_owned_void_p_retain,
  (NSMT_release_func_t) _NS_non_owned_void_p_release,
  (NSMT_describe_func_t) _NS_non_owned_void_p_describe,
  0
};

const NSMapTableKeyCallBacks NSNonOwnedPointerOrNullMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_non_owned_void_p_hash,
  (NSMT_is_equal_func_t) _NS_non_owned_void_p_is_equal,
  (NSMT_retain_func_t) _NS_non_owned_void_p_retain,
  (NSMT_release_func_t) _NS_non_owned_void_p_release,
  (NSMT_describe_func_t) _NS_non_owned_void_p_describe,
  /* FIXME: Oh my.  Is this really ok?  I did it in a moment of
   * weakness.  A fit of madness, I say!  And if this is wrong, what
   * *should* it be?!? */
  (const void *)-1
};

const NSMapTableKeyCallBacks NSNonRetainedObjectMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_non_retained_id_hash,
  (NSMT_is_equal_func_t) _NS_non_retained_id_is_equal,
  (NSMT_retain_func_t) _NS_non_retained_id_retain,
  (NSMT_release_func_t) _NS_non_retained_id_release,
  (NSMT_describe_func_t) _NS_non_retained_id_describe,
  0
};

const NSMapTableKeyCallBacks NSObjectMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_id_hash,
  (NSMT_is_equal_func_t) _NS_id_is_equal,
  (NSMT_retain_func_t) _NS_id_retain,
  (NSMT_release_func_t) _NS_id_release,
  (NSMT_describe_func_t) _NS_id_describe,
  0
};

const NSMapTableKeyCallBacks NSOwnedPointerMapKeyCallBacks = 
{
  (NSMT_hash_func_t) _NS_owned_void_p_hash,
  (NSMT_is_equal_func_t) _NS_owned_void_p_is_equal,
  (NSMT_retain_func_t) _NS_owned_void_p_retain,
  (NSMT_release_func_t) _NS_owned_void_p_release,
  (NSMT_describe_func_t) _NS_owned_void_p_describe,
  0
};

const NSMapTableValueCallBacks NSIntMapValueCallBacks = 
{
  (NSMT_retain_func_t) _NS_int_retain,
  (NSMT_release_func_t) _NS_int_release,
  (NSMT_describe_func_t) _NS_int_describe
};

const NSMapTableValueCallBacks NSNonOwnedPointerMapValueCallBacks = 
{
  (NSMT_retain_func_t) _NS_non_owned_void_p_retain,
  (NSMT_release_func_t) _NS_non_owned_void_p_release,
  (NSMT_describe_func_t) _NS_non_owned_void_p_describe
};

const NSMapTableValueCallBacks NSNonRetainedObjectMapValueCallBacks = 
{
  (NSMT_retain_func_t) _NS_non_retained_id_retain,
  (NSMT_release_func_t) _NS_non_retained_id_release,
  (NSMT_describe_func_t) _NS_non_retained_id_describe
};

const NSMapTableValueCallBacks NSObjectMapValueCallBacks = 
{
  (NSMT_retain_func_t) _NS_id_retain,
  (NSMT_release_func_t) _NS_id_release,
  (NSMT_describe_func_t) _NS_id_describe
};

const NSMapTableValueCallBacks NSOwnedPointerMapValueCallBacks = 
{
  (NSMT_retain_func_t) _NS_owned_void_p_retain,
  (NSMT_release_func_t) _NS_owned_void_p_release,
  (NSMT_describe_func_t) _NS_owned_void_p_describe
};

/** Standard NSHashTable callbacks... **/
     
const NSHashTableCallBacks NSIntHashCallBacks =
{
  (NSHT_hash_func_t) _NS_int_hash,
  (NSHT_isEqual_func_t) _NS_int_is_equal,
  (NSHT_retain_func_t) _NS_int_retain,
  (NSHT_release_func_t) _NS_int_release,
  (NSHT_describe_func_t) _NS_int_describe
};

const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks = 
{
  (NSHT_hash_func_t) _NS_non_owned_void_p_hash,
  (NSHT_isEqual_func_t) _NS_non_owned_void_p_is_equal,
  (NSHT_retain_func_t) _NS_non_owned_void_p_retain,
  (NSHT_release_func_t) _NS_non_owned_void_p_release,
  (NSHT_describe_func_t) _NS_non_owned_void_p_describe
};

const NSHashTableCallBacks NSNonRetainedObjectHashCallBacks = 
{
  (NSHT_hash_func_t) _NS_non_retained_id_hash,
  (NSHT_isEqual_func_t) _NS_non_retained_id_is_equal,
  (NSHT_retain_func_t) _NS_non_retained_id_retain,
  (NSHT_release_func_t) _NS_non_retained_id_release,
  (NSHT_describe_func_t) _NS_non_retained_id_describe
};

const NSHashTableCallBacks NSObjectHashCallBacks = 
{
  (NSHT_hash_func_t) _NS_id_hash,
  (NSHT_isEqual_func_t) _NS_id_is_equal,
  (NSHT_retain_func_t) _NS_id_retain,
  (NSHT_release_func_t) _NS_id_release,
  (NSHT_describe_func_t) _NS_id_describe
};

const NSHashTableCallBacks NSOwnedPointerHashCallBacks = 
{
  (NSHT_hash_func_t) _NS_owned_void_p_hash,
  (NSHT_isEqual_func_t) _NS_owned_void_p_is_equal,
  (NSHT_retain_func_t) _NS_owned_void_p_retain,
  (NSHT_release_func_t) _NS_owned_void_p_release,
  (NSHT_describe_func_t) _NS_owned_void_p_describe
};

const NSHashTableCallBacks NSPointerToStructHashCallBacks = 
{
  (NSHT_hash_func_t) _NS_int_p_hash,
  (NSHT_isEqual_func_t) _NS_int_p_is_equal,
  (NSHT_retain_func_t) _NS_int_p_retain,
  (NSHT_release_func_t) _NS_int_p_release,
  (NSHT_describe_func_t) _NS_int_p_describe
};

/* Callbacks for (NUL-terminated) arrays of `char'. */

/* FIXME: Is this right?!? */
#define _OBJECTS_NOT_A_CHAR_P_MARKER (const void *)(-1)

const void *o_not_a_char_p_marker = _OBJECTS_NOT_A_CHAR_P_MARKER;

o_callbacks_t o_callbacks_for_char_p = 
{
  (o_hash_func_t) o_char_p_hash,
  (o_compare_func_t) o_char_p_compare,
  (o_is_equal_func_t) o_char_p_is_equal,
  (o_retain_func_t) o_char_p_retain,
  (o_release_func_t) o_char_p_release,
  (o_describe_func_t) o_char_p_describe,
  _OBJECTS_NOT_A_CHAR_P_MARKER
};

/* Callbacks for `int' (and smaller) things. */

/* FIXME: This isn't right.  Fix it. */
#define _OBJECTS_NOT_AN_INT_MARKER (const void *)(-1)

const void *o_not_an_int_marker = _OBJECTS_NOT_AN_INT_MARKER;

o_callbacks_t o_callbacks_for_int = 
{
  (o_hash_func_t) o_int_hash,
  (o_compare_func_t) o_int_compare,
  (o_is_equal_func_t) o_int_is_equal,
  (o_retain_func_t) o_int_retain,
  (o_release_func_t) o_int_release,
  (o_describe_func_t) o_int_describe,
  _OBJECTS_NOT_AN_INT_MARKER
};

/* Callbacks for the Objective-C object type. */

/* FIXME: Is this right?!? */
#define _OBJECTS_NOT_AN_ID_MARKER (const void *)(-1)

const void *o_not_an_id_marker = _OBJECTS_NOT_AN_ID_MARKER;

o_callbacks_t o_callbacks_for_id = 
{
  (o_hash_func_t) o_id_hash,
  (o_compare_func_t) o_id_compare,
  (o_is_equal_func_t) o_id_is_equal,
  (o_retain_func_t) o_id_retain,
  (o_release_func_t) o_id_release,
  (o_describe_func_t) o_id_describe,
  _OBJECTS_NOT_AN_ID_MARKER
};

/* Callbacks for pointers to `int'. */

/* FIXME: Is this right?!? */
#define _OBJECTS_NOT_AN_INT_P_MARKER (const void *)(-1)

const void *o_not_an_int_p_marker = _OBJECTS_NOT_AN_INT_P_MARKER;

o_callbacks_t o_callbacks_for_int_p = 
{
  (o_hash_func_t) o_int_p_hash,
  (o_compare_func_t) o_int_p_compare,
  (o_is_equal_func_t) o_int_p_is_equal,
  (o_retain_func_t) o_int_p_retain,
  (o_release_func_t) o_int_p_release,
  (o_describe_func_t) o_int_p_describe,
  _OBJECTS_NOT_AN_INT_P_MARKER
};

/* Callbacks for pointers to `void'. */

/* FIXME: Is this right?!? */
#define _OBJECTS_NOT_A_VOID_P_MARKER (const void *)(-1)

const void *o_not_a_void_p_marker = _OBJECTS_NOT_A_VOID_P_MARKER;

o_callbacks_t o_callbacks_for_non_owned_void_p = 
{
  (o_hash_func_t) o_non_owned_void_p_hash,
  (o_compare_func_t) o_non_owned_void_p_compare,
  (o_is_equal_func_t) o_non_owned_void_p_is_equal,
  (o_retain_func_t) o_non_owned_void_p_retain,
  (o_release_func_t) o_non_owned_void_p_release,
  _OBJECTS_NOT_A_VOID_P_MARKER
};

o_callbacks_t o_callbacks_for_owned_void_p = 
{
  (o_hash_func_t) o_owned_void_p_hash,
  (o_compare_func_t) o_owned_void_p_compare,
  (o_is_equal_func_t) o_owned_void_p_is_equal,
  (o_retain_func_t) o_owned_void_p_retain,
  (o_release_func_t) o_owned_void_p_release,
  _OBJECTS_NOT_A_VOID_P_MARKER
};


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

@class	NSGCString;

/* Global lock to be used by classes when operating on any global
   data that invoke other methods which also access global; thus,
   creating the potential for deadlock. */
@class	NSRecursiveLock;
NSRecursiveLock *gnustep_global_lock = nil;

/*
 * Connection Notification Strings.
 */
NSString *NSConnectionDidDieNotification
  = @"NSConnectionDidDieNotification";
NSString *NSConnectionDidInitializeNotification
  = @"NSConnectionDidInitializeNotification";

/*
 * NSThread Notifications
 */
NSString *NSWillBecomeMultiThreadedNotification
  = @"NSWillBecomeMultiThreadedNotification";
NSString *NSThreadWillExitNotification
  = @"NSThreadWillExitNotification";

/*
 * Port Notifications
 */
NSString *PortBecameInvalidNotification
  = @"PortBecameInvalidNotification";
NSString *InPortClientBecameInvalidNotification
  = @"InPortClientBecameInvalidNotification";
NSString *InPortAcceptedClientNotification
  = @"InPortAcceptedClientNotification";

NSString *NSPortDidBecomeInvalidNotification
  = @"NSPortDidBecomeInvalidNotification";


/* RunLoop modes */
NSString *NSDefaultRunLoopMode
  = @"NSDefaultRunLoopMode";
NSString *NSConnectionReplyMode
  = @"NSConnectionReplyMode";


/* Exceptions */
NSString *NSCharacterConversionException
  = @"NSCharacterConversionException";
NSString *NSFailedAuthenticationException
  = @"NSFailedAuthenticationException";
NSString *NSGenericException
  = @"NSGenericException";
NSString *NSInconsistentArchiveException
  = @"NSInconsistentArchiveException";
NSString *NSInternalInconsistencyException
  = @"NSInternalInconsistencyException";
NSString *NSInvalidArgumentException
  = @"NSInvalidArgumentException";
NSString *NSMallocException
  = @"NSMallocException";
NSString *NSPortTimeoutException
  = @"NSPortTimeoutException";
NSString *NSRangeException
  = @"NSRangeException";

/* Exception handler */
NSUncaughtExceptionHandler *_NSUncaughtExceptionHandler;

/* NSBundle */
NSString *NSBundleDidLoadNotification
  = @"NSBundleDidLoadNotification";
NSString *NSShowNonLocalizedStrings
  = @"NSShowNonLocalizedStrings";
NSString *NSLoadedClasses
  = @"NSLoadedClasses";

/* Stream */
NSString *StreamException
  = @"StreamException";

/*
 * File attributes names
 */

/* File Attributes */

NSString *NSFileDeviceIdentifier
  = @"NSFileDeviceIdentifier";
NSString *NSFileGroupOwnerAccountName
  = @"NSFileGroupOwnerAccountName";
NSString *NSFileGroupOwnerAccountNumber
  = @"NSFileGroupOwnerAccountNumber";
NSString *NSFileModificationDate
  = @"NSFileModificationDate";
NSString *NSFileOwnerAccountName
  = @"NSFileOwnerAccountName";
NSString *NSFileOwnerAccountNumber
  = @"NSFileOwnerAccountNumber";
NSString *NSFilePosixPermissions
  = @"NSFilePosixPermissions";
NSString *NSFileReferenceCount
  = @"NSFileReferenceCount";
NSString *NSFileSize
  = @"NSFileSize";
NSString *NSFileSystemFileNumber
  = @"NSFileSystemFileNumber";
NSString *NSFileSystemNumber
  = @"NSFileSystemNumber";
NSString *NSFileType
  = @"NSFileType";

/* File Types */

NSString *NSFileTypeDirectory
  = @"NSFileTypeDirectory";
NSString *NSFileTypeRegular
  = @"NSFileTypeRegular";
NSString *NSFileTypeSymbolicLink
  = @"NSFileTypeSymbolicLink";
NSString *NSFileTypeSocket
  = @"NSFileTypeSocket";
NSString *NSFileTypeFifo
  = @"NSFileTypeFifo";
NSString *NSFileTypeCharacterSpecial
  = @"NSFileTypeCharacterSpecial";
NSString *NSFileTypeBlockSpecial
  = @"NSFileTypeBlockSpecial";
NSString *NSFileTypeUnknown
  = @"NSFileTypeUnknown";

/* FileSystem Attributes */

NSString *NSFileSystemSize
  = @"NSFileSystemSize";
NSString *NSFileSystemFreeSize
  = @"NSFileSystemFreeSize";
NSString *NSFileSystemNodes
  = @"NSFileSystemNodes";
NSString *NSFileSystemFreeNodes
  = @"NSFileSystemFreeNodes";

/* Standard domains */
NSString *NSArgumentDomain
  = @"NSArgumentDomain";
NSString *NSGlobalDomain
  = @"NSGlobalDomain";
NSString *NSRegistrationDomain
  = @"NSRegistrationDomain";

/* Public notification */
NSString *NSUserDefaultsDidChangeNotification
  = @"NSUserDefaultsDidChangeNotification";

/* Keys for language-dependent information */
NSString *NSWeekDayNameArray
  = @"NSWeekDayNameArray";
NSString *NSShortWeekDayNameArray
  = @"NSShortWeekDayNameArray";
NSString *NSMonthNameArray
  = @"NSMonthNameArray";
NSString *NSShortMonthNameArray
  = @"NSShortMonthNameArray";
NSString *NSTimeFormatString
  = @"NSTimeFormatString";
NSString *NSDateFormatString
  = @"NSDateFormatString";
NSString *NSShortDateFormatString
  = @"NSShortDateFormatString";
NSString *NSTimeDateFormatString
  = @"NSTimeDateFormatString";
NSString *NSShortTimeDateFormatString
  = @"NSShortTimeDateFormatString";
NSString *NSCurrencySymbol
  = @"NSCurrencySymbol";
NSString *NSDecimalSeparator
  = @"NSDecimalSeparator";
NSString *NSThousandsSeparator
  = @"NSThousandsSeparator";
NSString *NSInternationalCurrencyString
  = @"NSInternationalCurrencyString";
NSString *NSCurrencyString
  = @"NSCurrencyString";
NSString *NSNegativeCurrencyFormatString
  = @"NSNegativeCurrencyFormatString";
NSString *NSPositiveCurrencyFormatString
  = @"NSPositiveCurrencyFormatString";
NSString *NSDecimalDigits
  = @"NSDecimalDigits";
NSString *NSAMPMDesignation
  = @"NSAMPMDesignation";

NSString *NSHourNameDesignations
  = @"NSHourNameDesignations";
NSString *NSYearMonthWeekDesignations
  = @"NSYearMonthWeekDesignations";
NSString *NSEarlierTimeDesignations
  = @"NSEarlierTimeDesignations";
NSString *NSLaterTimeDesignations
  = @"NSLaterTimeDesignations";
NSString *NSThisDayDesignations
  = @"NSThisDayDesignations";
NSString *NSNextDayDesignations
  = @"NSNextDayDesignations";
NSString *NSNextNextDayDesignations
  = @"NSNextNextDayDesignations";
NSString *NSPriorDayDesignations
  = @"NSPriorDayDesignations";
NSString *NSDateTimeOrdering
  = @"NSDateTimeOrdering";

/* These are in OPENSTEP 4.2 */
NSString *NSLanguageCode
  = @"NSLanguageCode";
NSString *NSLanguageName
  = @"NSLanguageName";
NSString *NSFormalName
  = @"NSFormalName";

/*
 * Keys for the NSDictionary returned by [NSConnection -statistics]
 */
/* These in OPENSTEP 4.2 */
NSString *NSConnectionRepliesReceived
  = @"NSConnectionRepliesReceived";
NSString *NSConnectionRepliesSent
  = @"NSConnectionRepliesSent";
NSString *NSConnectionRequestsReceived
  = @"NSConnectionRequestsReceived";
NSString *NSConnectionRequestsSent
  = @"NSConnectionRequestsSent";
/* These Are GNUstep extras */
NSString *NSConnectionLocalCount
  = @"NSConnectionLocalCount";
NSString *NSConnectionProxyCount
  = @"NSConnectionProxyCount";

/*
 *	Setup function called when NSString is initialised.
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
	= [[NSGCString alloc] initWithCString:
	"InPortAcceptedClientNotification"];
      InPortClientBecameInvalidNotification
	= [[NSGCString alloc] initWithCString:
	"InPortClientBecameInvalidNotification"];
      NSAMPMDesignation
	= [[NSGCString alloc] initWithCString: "NSAMPMDesignation"];
      NSArgumentDomain
	= [[NSGCString alloc] initWithCString: "NSArgumentDomain"];
      NSBundleDidLoadNotification
	= [[NSGCString alloc] initWithCString: "NSBundleDidLoadNotification"];
      *(NSString**)&NSCharacterConversionException
	= [[NSGCString alloc] initWithCString: "NSCharacterConversionException"];
      NSConnectionDidDieNotification
	= [[NSGCString alloc] initWithCString: "NSConnectionDidDieNotification"];
      NSConnectionDidInitializeNotification
	= [[NSGCString alloc] initWithCString:
	"NSConnectionDidInitializeNotification"];
      NSConnectionLocalCount
	= [[NSGCString alloc] initWithCString: "NSConnectionLocalCount"];
      NSConnectionProxyCount
	= [[NSGCString alloc] initWithCString: "NSConnectionProxyCount"];
      NSConnectionRepliesReceived
	= [[NSGCString alloc] initWithCString: "NSConnectionRepliesReceived"];
      NSConnectionRepliesSent
	= [[NSGCString alloc] initWithCString: "NSConnectionRepliesSent"];
      NSConnectionReplyMode
	= [[NSGCString alloc] initWithCString: "NSConnectionReplyMode"];
      NSConnectionRequestsReceived
	= [[NSGCString alloc] initWithCString: "NSConnectionRequestsReceived"];
      NSConnectionRequestsSent
	= [[NSGCString alloc] initWithCString: "NSConnectionRequestsSent"];
      NSCurrencyString
	= [[NSGCString alloc] initWithCString: "NSCurrencyString"];
      NSCurrencySymbol
	= [[NSGCString alloc] initWithCString: "NSCurrencySymbol"];
      NSDateFormatString
	= [[NSGCString alloc] initWithCString: "NSDateFormatString"];
      NSDateTimeOrdering
	= [[NSGCString alloc] initWithCString: "NSDateTimeOrdering"];
      NSDecimalDigits
	= [[NSGCString alloc] initWithCString: "NSDecimalDigits"];
      NSDecimalSeparator
	= [[NSGCString alloc] initWithCString: "NSDecimalSeparator"];
      NSDefaultRunLoopMode
	= [[NSGCString alloc] initWithCString: "NSDefaultRunLoopMode"];
      NSEarlierTimeDesignations
	= [[NSGCString alloc] initWithCString: "NSEarlierTimeDesignations"];
      NSFailedAuthenticationException
	= [[NSGCString alloc] initWithCString: "NSFailedAuthenticationException"];
      NSFileDeviceIdentifier
	= [[NSGCString alloc] initWithCString: "NSFileDeviceIdentifier"];
      NSFileGroupOwnerAccountName
	= [[NSGCString alloc] initWithCString: "NSFileGroupOwnerAccountName"];
      NSFileGroupOwnerAccountNumber
	= [[NSGCString alloc] initWithCString: "NSFileGroupOwnerAccountNumber"];
      NSFileModificationDate
	= [[NSGCString alloc] initWithCString: "NSFileModificationDate"];
      NSFileOwnerAccountName
	= [[NSGCString alloc] initWithCString: "NSFileOwnerAccountName"];
      NSFileOwnerAccountNumber
	= [[NSGCString alloc] initWithCString: "NSFileOwnerAccountNumber"];
      NSFilePosixPermissions
	= [[NSGCString alloc] initWithCString: "NSFilePosixPermissions"];
      NSFileReferenceCount
	= [[NSGCString alloc] initWithCString: "NSFileReferenceCount"];
      NSFileSize
	= [[NSGCString alloc] initWithCString: "NSFileSize"];
      NSFileSystemFileNumber
	= [[NSGCString alloc] initWithCString: "NSFileSystemFileNumber"];
      NSFileSystemFreeNodes
	= [[NSGCString alloc] initWithCString: "NSFileSystemFreeNodes"];
      NSFileSystemFreeSize
	= [[NSGCString alloc] initWithCString: "NSFileSystemFreeSize"];
      NSFileSystemNodes
	= [[NSGCString alloc] initWithCString: "NSFileSystemNodes"];
      NSFileSystemNumber
	= [[NSGCString alloc] initWithCString: "NSFileSystemNumber"];
      NSFileSystemSize
	= [[NSGCString alloc] initWithCString: "NSFileSystemSize"];
      NSFileType
	= [[NSGCString alloc] initWithCString: "NSFileType"];
      NSFileTypeBlockSpecial
	= [[NSGCString alloc] initWithCString: "NSFileTypeBlockSpecial"];
      NSFileTypeCharacterSpecial
	= [[NSGCString alloc] initWithCString: "NSFileTypeCharacterSpecial"];
      NSFileTypeDirectory
	= [[NSGCString alloc] initWithCString: "NSFileTypeDirectory"];
      NSFileTypeFifo
	= [[NSGCString alloc] initWithCString: "NSFileTypeFifo"];
      NSFileTypeRegular
	= [[NSGCString alloc] initWithCString: "NSFileTypeRegular"];
      NSFileTypeSocket
	= [[NSGCString alloc] initWithCString: "NSFileTypeSocket"];
      NSFileTypeSymbolicLink
	= [[NSGCString alloc] initWithCString: "NSFileTypeSymbolicLink"];
      NSFileTypeUnknown
	= [[NSGCString alloc] initWithCString: "NSFileTypeUnknown"];
      NSFormalName
        = [[NSGCString alloc] initWithCString: "NSFormalName"];
      *(NSString**)&NSGenericException
	= [[NSGCString alloc] initWithCString: "NSGenericException"];
      NSGlobalDomain
	= [[NSGCString alloc] initWithCString: "NSGlobalDomain"];
      NSHourNameDesignations
	= [[NSGCString alloc] initWithCString: "NSHourNameDesignations"];
      NSInconsistentArchiveException
	= [[NSGCString alloc] initWithCString: "NSInconsistentArchiveException"];
      *(NSString**)&NSInternalInconsistencyException
	= [[NSGCString alloc] initWithCString:
	"NSInternalInconsistencyException"];
      NSInternationalCurrencyString
	= [[NSGCString alloc] initWithCString: "NSInternationalCurrencyString"];
      *(NSString**)&NSInvalidArgumentException
	= [[NSGCString alloc] initWithCString: "NSInvalidArgumentException"];
      NSLanguageCode
        = [[NSGCString alloc] initWithCString: "NSLanguageCode"];
      NSLanguageName
        = [[NSGCString alloc] initWithCString: "NSLanguageName"];
      NSLaterTimeDesignations
	= [[NSGCString alloc] initWithCString: "NSLaterTimeDesignations"];
      NSLoadedClasses
	= [[NSGCString alloc] initWithCString: "NSLoadedClasses"];
      *(NSString**)&NSMallocException
	= [[NSGCString alloc] initWithCString: "NSMallocException"];
      NSMonthNameArray
	= [[NSGCString alloc] initWithCString: "NSMonthNameArray"];
      NSNegativeCurrencyFormatString
        = [[NSGCString alloc] initWithCString: "NSNegativeCurrencyFormatString"];
      NSNextDayDesignations
	= [[NSGCString alloc] initWithCString: "NSNextDayDesignations"];
      NSNextNextDayDesignations
	= [[NSGCString alloc] initWithCString: "NSNextNextDayDesignations"];
      NSPortDidBecomeInvalidNotification
	= [[NSGCString alloc] initWithCString:
	"NSPortDidBecomeInvalidNotification"];
      NSPortTimeoutException
	= [[NSGCString alloc] initWithCString: "NSPortTimeoutException"];
      NSPositiveCurrencyFormatString
        = [[NSGCString alloc] initWithCString: "NSPositiveCurrencyFormatString"];
      NSPriorDayDesignations
	= [[NSGCString alloc] initWithCString: "NSPriorDayDesignations"];
      *(NSString**)&NSRangeException
	= [[NSGCString alloc] initWithCString: "NSRangeException"];
      NSRegistrationDomain
	= [[NSGCString alloc] initWithCString: "NSRegistrationDomain"];
      NSShortDateFormatString
        = [[NSGCString alloc] initWithCString: "NSShortDateFormatString"];
      NSShortMonthNameArray
	= [[NSGCString alloc] initWithCString: "NSShortMonthNameArray"];
      NSShortTimeDateFormatString
	= [[NSGCString alloc] initWithCString: "NSShortTimeDateFormatString"];
      NSShortWeekDayNameArray
	= [[NSGCString alloc] initWithCString: "NSShortWeekDayNameArray"];
      NSShowNonLocalizedStrings
	= [[NSGCString alloc] initWithCString: "NSShowNonLocalizedStrings"];
      NSThisDayDesignations
	= [[NSGCString alloc] initWithCString: "NSThisDayDesignations"];
      NSThousandsSeparator
	= [[NSGCString alloc] initWithCString: "NSThousandsSeparator"];
      NSThreadWillExitNotification
	= [[NSGCString alloc] initWithCString: "NSThreadWillExitNotification"];
      NSTimeDateFormatString
	= [[NSGCString alloc] initWithCString: "NSTimeDateFormatString"];
      NSTimeFormatString
	= [[NSGCString alloc] initWithCString: "NSTimeFormatString"];
      NSUserDefaultsDidChangeNotification
	= [[NSGCString alloc] initWithCString:
	"NSUserDefaultsDidChangeNotification"];
      NSWeekDayNameArray
	= [[NSGCString alloc] initWithCString: "NSWeekDayNameArray"];
      NSWillBecomeMultiThreadedNotification
	= [[NSGCString alloc] initWithCString:
	"NSWillBecomeMultiThreadedNotification"];
      NSYearMonthWeekDesignations
	= [[NSGCString alloc] initWithCString: "NSYearMonthWeekDesignations"];
      PortBecameInvalidNotification
	= [[NSGCString alloc] initWithCString: "PortBecameInvalidNotification"];
      StreamException
	= [[NSGCString alloc] initWithCString: "StreamException"];
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


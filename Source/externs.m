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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
   */ 

#include <config.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSMapTable.h>
#include "NSCallBacks.h"
#include <Foundation/NSHashTable.h>
#include <Foundation/NSLock.h>

/* Global lock to be used by classes when operating on any global
   data that invoke other methods which also access global; thus,
   creating the potential for deadlock. */
NSRecursiveLock *gnustep_global_lock = nil;

/* Connection Notification Strings. */

NSString *ConnectionBecameInvalidNotification = 
@"ConnectionBecameInvalidNotification";

NSString *ConnectionWasCreatedNotification = 
@"ConnectionWasCreatedNotification";

/* NSThread Notifications */
NSString *NSWillBecomeMultiThreadedNotification
  = @"NSWillBecomeMultiThreadedNotification";
NSString *NSThreadWillExitNotification
  = @"NSThreadWillExitNotification";

/* Port Notifications */
NSString *PortBecameInvalidNotification = @"PortBecameInvalidNotification";

NSString *InPortClientBecameInvalidNotification = 
@"InPortClientBecameInvalidNotification";

NSString *InPortAcceptedClientNotification = 
@"InPortAcceptedClientNotification";

/* RunLoop modes */
NSString *RunLoopConnectionReplyMode = @"RunLoopConnectionReplyMode";

/* RunLoop mode strings. */
id RunLoopDefaultMode = @"RunLoopDefaultMode";

/* Exceptions */
NSString *NSInconsistentArchiveException = @"NSInconsistentArchiveException";
NSString *NSGenericException = @"NSGenericException";
NSString *NSInternalInconsistencyException = 
@"NSInternalInconsistencyException";
NSString *NSInvalidArgumentException = @"NSInvalidArgumentException";
NSString *NSMallocException = @"NSMallocException";
NSString *NSRangeException = @"NSRangeException";

/* Exception handler */
NSUncaughtExceptionHandler *_NSUncaughtExceptionHandler;

/* NSBundle */
NSString* NSBundleDidLoadNotification = @"NSBundleDidLoadNotification";
NSString* NSShowNonLocalizedStrings = @"NSShowNonLocalizedStrings";
NSString* NSLoadedClasses = @"NSLoadedClasses";

/* Stream */
NSString* StreamException = @"StreamException";

/*
 * File attributes names
 */

/* File Attributes */

NSString* const NSFileDeviceIdentifier = @"NSFileDeviceIdentifier";
NSString* const NSFileGroupOwnerAccountName = @"NSFileGroupOwnerAccountName";
NSString* const NSFileGroupOwnerAccountNumber = @"NSFileGroupOwnerAccountNumber";
NSString* const NSFileModificationDate = @"NSFileModificationDate";
NSString* const NSFileOwnerAccountName = @"NSFileOwnerAccountName";
NSString* const NSFileOwnerAccountNumber = @"NSFileOwnerAccountNumber";
NSString* const NSFilePosixPermissions = @"NSFilePosixPermissions";
NSString* const NSFileReferenceCount = @"NSFileReferenceCount";
NSString* const NSFileSize = @"NSFileSize";
NSString* const NSFileSystemFileNumber = @"NSFileSystemFileNumber";
NSString* const NSFileSystemNumber = @"NSFileSystemNumber";
NSString* const NSFileType = @"NSFileType";

/* File Types */

NSString* const NSFileTypeDirectory = @"NSFileTypeDirectory";
NSString* const NSFileTypeRegular = @"NSFileTypeRegular";
NSString* const NSFileTypeSymbolicLink = @"NSFileTypeSymbolicLink";
NSString* const NSFileTypeSocket = @"NSFileTypeSocket";
NSString* const NSFileTypeFifo = @"NSFileTypeFifo";
NSString* const NSFileTypeCharacterSpecial = @"NSFileTypeCharacterSpecial";
NSString* const NSFileTypeBlockSpecial = @"NSFileTypeBlockSpecial";
NSString* const NSFileTypeUnknown = @"NSFileTypeUnknown";

/* FileSystem Attributes */

NSString* const NSFileSystemSize = @"NSFileSystemSize";
NSString* const NSFileSystemFreeSize = @"NSFileSystemFreeSize";
NSString* const NSFileSystemNodes = @"NSFileSystemNodes";
NSString* const NSFileSystemFreeNodes = @"NSFileSystemFreeNodes";

/* Standard domains */
NSString* const NSArgumentDomain = @"NSArgumentDomain";
NSString* const NSGlobalDomain = @"NSGlobalDomain";
NSString* const NSRegistrationDomain = @"NSRegistrationDomain";

/* Public notification */
NSString* const NSUserDefaultsDidChangeNotification = @"NSUserDefaultsDidChangeNotification";

/* Keys for language-dependent information */
NSString* const NSWeekDayNameArray = @"NSWeekDayNameArray";
NSString* const NSShortWeekDayNameArray = @"NSShortWeekDayNameArray";
NSString* const NSMonthNameArray = @"NSMonthNameArray";
NSString* const NSShortMonthNameArray = @"NSShortMonthNameArray";
NSString* const NSTimeFormatString = @"NSTimeFormatString";
NSString* const NSDateFormatString = @"NSDateFormatString";
NSString* const NSTimeDateFormatString = @"NSTimeDateFormatString";
NSString* const NSShortTimeDateFormatString = @"NSShortTimeDateFormatString";
NSString* const NSCurrencySymbol = @"NSCurrencySymbol";
NSString* const NSDecimalSeparator = @"NSDecimalSeparator";
NSString* const NSThousandsSeparator = @"NSThousandsSeparator";
NSString* const NSInternationalCurrencyString = @"NSInternationalCurrencyString";
NSString* const NSCurrencyString = @"NSCurrencyString";
NSString* const NSDecimalDigits = @"NSDecimalDigits";
NSString* const NSAMPMDesignation = @"NSAMPMDesignation";

NSString* const NSHourNameDesignations = @"NSHourNameDesignations";
NSString* const NSYearMonthWeekDesignations = @"NSYearMonthWeekDesignations";
NSString* const NSEarlierTimeDesignations = @"NSEarlierTimeDesignations";
NSString* const NSLaterTimeDesignations = @"NSLaterTimeDesignations";
NSString* const NSThisDayDesignations = @"NSThisDayDesignations";
NSString* const NSNextDayDesignations = @"NSNextDayDesignations";
NSString* const NSNextNextDayDesignations = @"NSNextNextDayDesignations";
NSString* const NSPriorDayDesignations = @"NSPriorDayDesignations";
NSString* const NSDateTimeOrdering = @"NSDateTimeOrdering";

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


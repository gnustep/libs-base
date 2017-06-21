/** All of the external data
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Scott Christley <scottc@net-community.com>
   Date: August 1997

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */

#import "common.h"

#import "Foundation/NSArray.h"
#import "Foundation/NSException.h"

#import "GSPrivate.h"

/*
 PENDING some string constants are scattered about in the class impl
         files and should be moved here
         furthermore, the test for this in Testing/exported-strings.m
         needs to be updated
*/


/*
 * NSConnection Notification Strings.
 */
NSString *NSConnectionDidDieNotification = @"NSConnectionDidDieNotification";

NSString *NSConnectionDidInitializeNotification = @"NSConnectionDidInitializeNotification";


/*
 * NSDistributedNotificationCenter types.
 */
NSString *NSLocalNotificationCenterType = @"NSLocalNotificationCenterType";
NSString *GSNetworkNotificationCenterType = @"GSNetworkNotificationCenterType";
NSString *GSPublicNotificationCenterType = @"GSPublicNotificationCenterType";

/*
 * NSThread Notifications
 */
NSString *NSWillBecomeMultiThreadedNotification = @"NSWillBecomeMultiThreadedNotification";

NSString *NSThreadDidStartNotification = @"NSThreadDidStartNotification";

NSString *NSThreadWillExitNotification = @"NSThreadWillExitNotification";


/*
 * Port Notifications
 */

NSString *NSPortDidBecomeInvalidNotification = @"NSPortDidBecomeInvalidNotification";

/* NSTask notifications */
NSString *NSTaskDidTerminateNotification = @"NSTaskDidTerminateNotification";

/* NSUndoManager notifications */
NSString *NSUndoManagerCheckpointNotification = @"NSUndoManagerCheckpointNotification";

NSString *NSUndoManagerDidOpenUndoGroupNotification = @"NSUndoManagerDidOpenUndoGroupNotification";

NSString *NSUndoManagerDidRedoChangeNotification = @"NSUndoManagerDidRedoChangeNotification";

NSString *NSUndoManagerDidUndoChangeNotification = @"NSUndoManagerDidUndoChangeNotification";

NSString *NSUndoManagerWillCloseUndoGroupNotification = @"NSUndoManagerWillCloseUndoGroupNotification";

NSString *NSUndoManagerWillRedoChangeNotification = @"NSUndoManagerWillRedoChangeNotification";

NSString *NSUndoManagerWillUndoChangeNotification = @"NSUndoManagerWillUndoChangeNotification";


/* NSURL constants */
NSString *NSURLFileScheme = @"file";

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
NSString *NSURLNameKey = @"NSURLNameKey";
NSString *NSURLLocalizedNameKey = @"NSURLLocalizedNameKey";
NSString *NSURLIsRegularFileKey = @"NSURLIsRegularFileKey";
NSString *NSURLIsDirectoryKey = @"NSURLIsDirectoryKey";
NSString *NSURLIsSymbolicLinkKey = @"NSURLIsSymbolicLinkKey";
NSString *NSURLIsVolumeKey = @"NSURLIsVolumeKey";
NSString *NSURLIsPackageKey = @"NSURLIsPackageKey";
NSString *NSURLIsSystemImmutableKey = @"NSURLIsSystemImmutableKey";
NSString *NSURLIsUserImmutableKey = @"NSURLIsUserImmutableKey";
NSString *NSURLIsHiddenKey = @"NSURLIsHiddenKey";
NSString *NSURLHasHiddenExtensionKey = @"NSURLHasHiddenExtensionKey";
NSString *NSURLCreationDateKey = @"NSURLCreationDateKey";
NSString *NSURLContentAccessDateKey = @"NSURLContentAccessDateKey";
NSString *NSURLContentModificationDateKey = @"NSURLContentModificationDateKey";
NSString *NSURLAttributeModificationDateKey = @"NSURLAttributeModificationDateKey";
NSString *NSURLLinkCountKey = @"NSURLLinkCountKey";
NSString *NSURLParentDirectoryURLKey = @"NSURLParentDirectoryURLKey";
NSString *NSURLVolumeURLKey = @"NSURLVolumeURLKey";
NSString *NSURLTypeIdentifierKey = @"NSURLTypeIdentifierKey";
NSString *NSURLLocalizedTypeDescriptionKey = @"NSURLLocalizedTypeDescriptionKey";
NSString *NSURLLabelNumberKey = @"NSURLLabelNumberKey";
NSString *NSURLLabelColorKey = @"NSURLLabelColorKey";
NSString *NSURLLocalizedLabelKey = @"NSURLLocalizedLabelKey";
NSString *NSURLEffectiveIconKey = @"NSURLEffectiveIconKey";
NSString *NSURLCustomIconKey = @"NSURLCustomIconKey";
NSString *NSURLFileSizeKey = @"NSURLFileSizeKey";
NSString *NSURLFileAllocatedSizeKey = @"NSURLFileAllocatedSizeKey";
NSString *NSURLIsAliasFileKey = @"NSURLIsAliasFileKey";
NSString *NSURLVolumeLocalizedFormatDescriptionKey = @"NSURLVolumeLocalizedFormatDescriptionKey";
NSString *NSURLVolumeTotalCapacityKey = @"NSURLVolumeTotalCapacityKey";
NSString *NSURLVolumeAvailableCapacityKey = @"NSURLVolumeAvailableCapacityKey";
NSString *NSURLVolumeResourceCountKey = @"NSURLVolumeResourceCountKey";
NSString *NSURLVolumeSupportsPersistentIDsKey = @"NSURLVolumeSupportsPersistentIDsKey";
NSString *NSURLVolumeSupportsSymbolicLinksKey = @"NSURLVolumeSupportsSymbolicLinksKey";
NSString *NSURLVolumeSupportsHardLinksKey = @"NSURLVolumeSupportsHardLinksKey";
NSString *NSURLVolumeSupportsJournalingKey = @"NSURLVolumeSupportsJournalingKey";
NSString *NSURLVolumeIsJournalingKey = @"NSURLVolumeIsJournalingKey";
NSString *NSURLVolumeSupportsSparseFilesKey = @"NSURLVolumeSupportsSparseFilesKey";
NSString *NSURLVolumeSupportsZeroRunsKey = @"NSURLVolumeSupportsZeroRunsKey";
NSString *NSURLVolumeSupportsCaseSensitiveNamesKey = @"NSURLVolumeSupportsCaseSensitiveNamesKey";
NSString *NSURLVolumeSupportsCasePreservedNamesKey = @"NSURLVolumeSupportsCasePreservedNamesKey";
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)
NSString *NSURLFileResourceIdentifierKey = @"NSURLFileResourceIdentifierKey";
NSString *NSURLVolumeIdentifierKey = @"NSURLVolumeIdentifierKey";
NSString *NSURLPreferredIOBlockSizeKey = @"NSURLPreferredIOBlockSizeKey";
NSString *NSURLIsReadableKey = @"NSURLIsReadableKey";
NSString *NSURLIsWritableKey = @"NSURLIsWritableKey";
NSString *NSURLIsExecutableKey = @"NSURLIsExecutableKey";
NSString *NSURLFileSecurityKey = @"NSURLFileSecurityKey";
NSString *NSURLIsMountTriggerKey = @"NSURLIsMountTriggerKey";
NSString *NSURLFileResourceTypeKey = @"NSURLFileResourceTypeKey";
NSString *NSURLTotalFileSizeKey = @"NSURLTotalFileSizeKey";
NSString *NSURLTotalFileAllocatedSizeKey = @"NSURLTotalFileAllocatedSizeKey";
NSString *NSURLVolumeSupportsRootDirectoryDatesKey = @"NSURLVolumeSupportsRootDirectoryDatesKey";
NSString *NSURLVolumeSupportsVolumeSizesKey = @"NSURLVolumeSupportsVolumeSizesKey";
NSString *NSURLVolumeSupportsRenamingKey = @"NSURLVolumeSupportsRenamingKey";
NSString *NSURLVolumeSupportsAdvisoryFileLockingKey = @"NSURLVolumeSupportsAdvisoryFileLockingKey";
NSString *NSURLVolumeSupportsExtendedSecurityKey = @"NSURLVolumeSupportsExtendedSecurityKey";
NSString *NSURLVolumeIsBrowsableKey = @"NSURLVolumeIsBrowsableKey";
NSString *NSURLVolumeMaximumFileSizeKey = @"NSURLVolumeMaximumFileSizeKey";
NSString *NSURLVolumeIsEjectableKey = @"NSURLVolumeIsEjectableKey";
NSString *NSURLVolumeIsRemovableKey = @"NSURLVolumeIsRemovableKey";
NSString *NSURLVolumeIsInternalKey = @"NSURLVolumeIsInternalKey";
NSString *NSURLVolumeIsAutomountedKey = @"NSURLVolumeIsAutomountedKey";
NSString *NSURLVolumeIsLocalKey = @"NSURLVolumeIsLocalKey";
NSString *NSURLVolumeIsReadOnlyKey = @"NSURLVolumeIsReadOnlyKey";
NSString *NSURLVolumeCreationDateKey = @"NSURLVolumeCreationDateKey";
NSString *NSURLVolumeURLForRemountingKey = @"NSURLVolumeURLForRemountingKey";
NSString *NSURLVolumeUUIDStringKey = @"NSURLVolumeUUIDStringKey";
NSString *NSURLVolumeNameKey = @"NSURLVolumeNameKey";
NSString *NSURLVolumeLocalizedNameKey = @"NSURLVolumeLocalizedNameKey";
NSString *NSURLIsUbiquitousItemKey = @"NSURLIsUbiquitousItemKey";
NSString *NSURLUbiquitousItemHasUnresolvedConflictsKey = @"NSURLUbiquitousItemHasUnresolvedConflictsKey";
NSString *NSURLUbiquitousItemIsDownloadingKey = @"NSURLUbiquitousItemIsDownloadingKey";
NSString *NSURLUbiquitousItemIsUploadedKey = @"NSURLUbiquitousItemIsUploadedKey";
NSString *NSURLUbiquitousItemIsUploadingKey = @"NSURLUbiquitousItemIsUploadingKey";
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_8, GS_API_LATEST)
NSString *NSURLIsExcludedFromBackupKey = @"NSURLIsExcludedFromBackupKey";
NSString *NSURLPathKey = @"NSURLPathKey";
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_9, GS_API_LATEST)
NSString *NSURLTagNamesKey = @"NSURLTagNamesKey";
NSString *NSURLUbiquitousItemDownloadingStatusKey = @"NSURLUbiquitousItemDownloadingStatusKey";
NSString *NSURLUbiquitousItemDownloadingErrorKey = @"NSURLUbiquitousItemDownloadingErrorKey";
NSString *NSURLUbiquitousItemUploadingErrorKey = @"NSURLUbiquitousItemUploadingErrorKey";
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_10, GS_API_LATEST)
NSString *NSURLGenerationIdentifierKey = @"NSURLGenerationIdentifierKey";
NSString *NSURLDocumentIdentifierKey = @"NSURLDocumentIdentifierKey";
NSString *NSURLAddedToDirectoryDateKey = @"NSURLAddedToDirectoryDateKey";
NSString *NSURLQuarantinePropertiesKey = @"NSURLQuarantinePropertiesKey";
NSString *NSThumbnail1024x1024SizeKey = @"NSThumbnail1024x1024SizeKey";
NSString *NSURLUbiquitousItemDownloadRequestedKey = @"NSURLUbiquitousItemDownloadRequestedKey";
NSString *NSURLUbiquitousItemContainerDisplayNameKey = @"NSURLUbiquitousItemContainerDisplayNameKey";
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
NSString *NSURLIsApplicationKey = @"NSURLIsApplicationKey";
NSString *NSURLApplicationIsScriptableKey = @"NSURLApplicationIsScriptableKey";
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)
NSString *NSURLFileResourceTypeNamedPipe = @"NSURLFileResourceTypeNamedPipe";
NSString *NSURLFileResourceTypeCharacterSpecial = @"NSURLFileResourceTypeCharacterSpecial";
NSString *NSURLFileResourceTypeDirectory = @"NSURLFileResourceTypeDirectory";
NSString *NSURLFileResourceTypeBlockSpecial = @"NSURLFileResourceTypeBlockSpecial";
NSString *NSURLFileResourceTypeRegular = @"NSURLFileResourceTypeRegular";
NSString *NSURLFileResourceTypeSymbolicLink = @"NSURLFileResourceTypeSymbolicLink";
NSString *NSURLFileResourceTypeSocket = @"NSURLFileResourceTypeSocket";
NSString *NSURLFileResourceTypeUnknown = @"NSURLFileResourceTypeUnknown";
#endif

/** Possible values for Ubiquitous Item Downloading Key **/
#if OS_API_VERSION(MAC_OS_X_VERSION_10_9, GS_API_LATEST)
NSString *NSURLUbiquitousItemDownloadingStatusNotDownloaded = @"NSURLUbiquitousItemDownloadingStatusNotDownloaded";
NSString *NSURLUbiquitousItemDownloadingStatusDownloaded = @"NSURLUbiquitousItemDownloadingStatusDownloaded";
NSString *NSURLUbiquitousItemDownloadingStatusCurrent = @"NSURLUbiquitousItemDownloadingStatusCurrent";
#endif

/* RunLoop modes */
NSString *NSConnectionReplyMode = @"NSConnectionReplyMode";

/* NSValueTransformer constants */
NSString *const NSNegateBooleanTransformerName
  = @"NSNegateBoolean";
NSString *const NSIsNilTransformerName
  = @"NSIsNil";
NSString *const NSIsNotNilTransformerName
  = @"NSIsNotNil"; 
NSString *const NSUnarchiveFromDataTransformerName
  = @"NSUnarchiveFromData";


/* Standard domains */
NSString *NSArgumentDomain = @"NSArgumentDomain";

NSString *NSGlobalDomain = @"NSGlobalDomain";

NSString *NSRegistrationDomain = @"NSRegistrationDomain";

NSString *GSConfigDomain = @"GSConfigDomain";


/* Public notification */
NSString *NSUserDefaultsDidChangeNotification = @"NSUserDefaultsDidChangeNotification";


/* Keys for language-dependent information */
NSString *NSWeekDayNameArray = @"NSWeekDayNameArray";

NSString *NSShortWeekDayNameArray = @"NSShortWeekDayNameArray";

NSString *NSMonthNameArray = @"NSMonthNameArray";

NSString *NSShortMonthNameArray = @"NSShortMonthNameArray";

NSString *NSTimeFormatString = @"NSTimeFormatString";

NSString *NSDateFormatString = @"NSDateFormatString";

NSString *NSShortDateFormatString = @"NSShortDateFormatString";

NSString *NSTimeDateFormatString = @"NSTimeDateFormatString";

NSString *NSShortTimeDateFormatString = @"NSShortTimeDateFormatString";

NSString *NSCurrencySymbol = @"NSCurrencySymbol";

NSString *NSDecimalSeparator = @"NSDecimalSeparator";

NSString *NSThousandsSeparator = @"NSThousandsSeparator";

NSString *NSInternationalCurrencyString = @"NSInternationalCurrencyString";

NSString *NSCurrencyString = @"NSCurrencyString";

NSString *NSNegativeCurrencyFormatString = @"NSNegativeCurrencyFormatString";

NSString *NSPositiveCurrencyFormatString = @"NSPositiveCurrencyFormatString";

NSString *NSDecimalDigits = @"NSDecimalDigits";

NSString *NSAMPMDesignation = @"NSAMPMDesignation";


NSString *NSHourNameDesignations = @"NSHourNameDesignations";

NSString *NSYearMonthWeekDesignations = @"NSYearMonthWeekDesignations";

NSString *NSEarlierTimeDesignations = @"NSEarlierTimeDesignations";

NSString *NSLaterTimeDesignations = @"NSLaterTimeDesignations";

NSString *NSThisDayDesignations = @"NSThisDayDesignations";

NSString *NSNextDayDesignations = @"NSNextDayDesignations";

NSString *NSNextNextDayDesignations = @"NSNextNextDayDesignations";

NSString *NSPriorDayDesignations = @"NSPriorDayDesignations";

NSString *NSDateTimeOrdering = @"NSDateTimeOrdering";


/* These are in OPENSTEP 4.2 */
NSString *NSLanguageCode = @"NSLanguageCode";

NSString *NSLanguageName = @"NSLanguageName";

NSString *NSFormalName = @"NSFormalName";

/* For GNUstep */
NSString *GSLocale = @"GSLocale";


/*
 * Keys for the NSDictionary returned by [NSConnection -statistics]
 */
/* These in OPENSTEP 4.2 */
NSString *NSConnectionRepliesReceived = @"NSConnectionRepliesReceived";

NSString *NSConnectionRepliesSent = @"NSConnectionRepliesSent";

NSString *NSConnectionRequestsReceived = @"NSConnectionRequestsReceived";

NSString *NSConnectionRequestsSent = @"NSConnectionRequestsSent";

/* These Are GNUstep extras */
NSString *NSConnectionLocalCount = @"NSConnectionLocalCount";

NSString *NSConnectionProxyCount = @"NSConnectionProxyCount";

/* Class description notification */
NSString *NSClassDescriptionNeededForClassNotification = @"NSClassDescriptionNeededForClassNotification";


/*
 * Optimization function called when NSObject is initialised.
 * We replace all the constant strings so they can
 * cache their hash values and be used much more efficiently as keys in
 * dictionaries etc.
 * We initialize with constant strings so that
 * code executed before NSObject +initialize calls us,
 * will have valid values.
 */

void
GSPrivateBuildStrings()
{
  static Class	NSStringClass = 0;

  if (NSStringClass == 0)
    {
      NSStringClass = [NSString class];

      /*
       * Ensure that NSString is initialized ... because we are called
       * from [NSObject +initialize] which might be executing as a
       * result of a call to [NSString +initialize] !
       * Use performSelector: to avoid compiler warning about clash of
       * return value types in two different versions of initialize.
       */
      [NSStringClass performSelector: @selector(initialize)];

      GS_REPLACE_CONSTANT_STRING(GSNetworkNotificationCenterType);
      GS_REPLACE_CONSTANT_STRING(NSAMPMDesignation);
      GS_REPLACE_CONSTANT_STRING(NSArgumentDomain);
      GS_REPLACE_CONSTANT_STRING(NSClassDescriptionNeededForClassNotification);
      GS_REPLACE_CONSTANT_STRING(NSConnectionDidDieNotification);
      GS_REPLACE_CONSTANT_STRING(NSConnectionDidInitializeNotification);
      GS_REPLACE_CONSTANT_STRING(NSConnectionLocalCount);
      GS_REPLACE_CONSTANT_STRING(NSConnectionProxyCount);
      GS_REPLACE_CONSTANT_STRING(NSConnectionRepliesReceived);
      GS_REPLACE_CONSTANT_STRING(NSConnectionRepliesSent);
      GS_REPLACE_CONSTANT_STRING(NSConnectionReplyMode);
      GS_REPLACE_CONSTANT_STRING(NSConnectionRequestsReceived);
      GS_REPLACE_CONSTANT_STRING(NSConnectionRequestsSent);
      GS_REPLACE_CONSTANT_STRING(NSCurrencyString);
      GS_REPLACE_CONSTANT_STRING(NSCurrencySymbol);
      GS_REPLACE_CONSTANT_STRING(NSDateFormatString);
      GS_REPLACE_CONSTANT_STRING(NSDateTimeOrdering);
      GS_REPLACE_CONSTANT_STRING(NSDecimalDigits);
      GS_REPLACE_CONSTANT_STRING(NSDecimalSeparator);
      GS_REPLACE_CONSTANT_STRING(NSEarlierTimeDesignations);
      GS_REPLACE_CONSTANT_STRING(NSFormalName);
      GS_REPLACE_CONSTANT_STRING(NSGlobalDomain);
      GS_REPLACE_CONSTANT_STRING(NSHourNameDesignations);
      GS_REPLACE_CONSTANT_STRING(NSInternationalCurrencyString);
      GS_REPLACE_CONSTANT_STRING(NSLanguageCode);
      GS_REPLACE_CONSTANT_STRING(NSLanguageName);
      GS_REPLACE_CONSTANT_STRING(NSLaterTimeDesignations);
      GS_REPLACE_CONSTANT_STRING(GSLocale);
      GS_REPLACE_CONSTANT_STRING(NSLocalNotificationCenterType);
      GS_REPLACE_CONSTANT_STRING(NSMonthNameArray);
      GS_REPLACE_CONSTANT_STRING(NSNegativeCurrencyFormatString);
      GS_REPLACE_CONSTANT_STRING(NSNextDayDesignations);
      GS_REPLACE_CONSTANT_STRING(NSNextNextDayDesignations);
      GS_REPLACE_CONSTANT_STRING(NSPortDidBecomeInvalidNotification);
      GS_REPLACE_CONSTANT_STRING(NSPositiveCurrencyFormatString);
      GS_REPLACE_CONSTANT_STRING(NSPriorDayDesignations);
      GS_REPLACE_CONSTANT_STRING(NSRegistrationDomain);
      GS_REPLACE_CONSTANT_STRING(NSShortDateFormatString);
      GS_REPLACE_CONSTANT_STRING(NSShortMonthNameArray);
      GS_REPLACE_CONSTANT_STRING(NSShortTimeDateFormatString);
      GS_REPLACE_CONSTANT_STRING(NSShortWeekDayNameArray);
      GS_REPLACE_CONSTANT_STRING(NSTaskDidTerminateNotification);
      GS_REPLACE_CONSTANT_STRING(NSThisDayDesignations);
      GS_REPLACE_CONSTANT_STRING(NSThousandsSeparator);
      GS_REPLACE_CONSTANT_STRING(NSThreadDidStartNotification);
      GS_REPLACE_CONSTANT_STRING(NSThreadWillExitNotification);
      GS_REPLACE_CONSTANT_STRING(NSTimeDateFormatString);
      GS_REPLACE_CONSTANT_STRING(NSTimeFormatString);
      GS_REPLACE_CONSTANT_STRING(NSUndoManagerCheckpointNotification);
      GS_REPLACE_CONSTANT_STRING(NSUndoManagerDidOpenUndoGroupNotification);
      GS_REPLACE_CONSTANT_STRING(NSUndoManagerDidRedoChangeNotification);
      GS_REPLACE_CONSTANT_STRING(NSUndoManagerDidUndoChangeNotification);
      GS_REPLACE_CONSTANT_STRING(NSUndoManagerWillCloseUndoGroupNotification);
      GS_REPLACE_CONSTANT_STRING(NSUndoManagerWillRedoChangeNotification);
      GS_REPLACE_CONSTANT_STRING(NSUndoManagerWillUndoChangeNotification);
      GS_REPLACE_CONSTANT_STRING(NSURLFileScheme);
      GS_REPLACE_CONSTANT_STRING(NSUserDefaultsDidChangeNotification);
      GS_REPLACE_CONSTANT_STRING(NSWeekDayNameArray);
      GS_REPLACE_CONSTANT_STRING(NSWillBecomeMultiThreadedNotification);
      GS_REPLACE_CONSTANT_STRING(NSYearMonthWeekDesignations);
    }
}



/* For bug in gcc 3.1. See NSByteOrder.h */
void _gcc3_1_hack(void){}

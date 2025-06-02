#ifndef	_INCLUDED_NSPROPERTYLISTPRIVATE_H
#define	_INCLUDED_NSPROPERTYLISTPRIVATE_H

#import  <Foundation/NSPropertyList.h>

@interface NSPropertyListSerialization (CheckFormat)
    // Checks if the content of data is a property list.
    // Returns 0 if not a binary plist (NSPropertyListBinaryFormat_v1_0),
    // GNUstep binary plist, or XML plist.
    + (NSPropertyListFormat) formatFromData: (NSData *) data; 
@end

#endif // _INCLUDED_NSPROPERTYLISTPRIVATE_H
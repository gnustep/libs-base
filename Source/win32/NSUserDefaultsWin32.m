#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSProcessInfo.h>

extern void GSPropertyListMake(id,NSDictionary*,BOOL,BOOL,unsigned,id*);

@interface NSUserDefaultsWin32 : NSUserDefaults
{
  BOOL noLegacyFile;
  NSString *registryPrefix;
  NSMapTable *registryInfo;
}
@end

@interface NSUserDefaults (Secrets)
- (BOOL) wantToReadDefaultsSince: (NSDate*)lastSyncDate;
- (BOOL) lockDefaultsFile: (BOOL*)wasLocked;
- (void) unlockDefaultsFile;
- (NSMutableDictionary*) readDefaults;
- (BOOL) writeDefaults: (NSDictionary*)defaults oldData: (NSDictionary*)oldData;
@end

struct NSUserDefaultsWin32_DomainInfo
{
  HKEY userKey;
  HKEY systemKey;
};

@implementation NSUserDefaults (Win32)
+ (Class) standardUserDefaultsClass
{
  return [NSUserDefaultsWin32 class];
}
@end

@implementation NSUserDefaultsWin32
- (id) initWithUser: (NSString*)userName
{
  NSFileManager	*mgr;
  NSString *path;
  NSString *file;

  NSAssert([userName isEqual: NSUserName()],
    @"NSUserDefaultsWin32 doesn't support reading/writing to users other than the current user.");
	
  mgr = [NSFileManager defaultManager];
  path = GSDefaultsRootForUser(userName);
  file = [path stringByAppendingPathComponent: @".GNUstepDefaults"];
  registryPrefix = [[NSString alloc] initWithString: @"Software\\GNUstep\\"];
	
  if ([mgr isReadableFileAtPath: file] == NO)
    {
      noLegacyFile = YES;
      self = [super initWithContentsOfFile: @"C: /No/Such/File/Exists"];
    }
  else
    {
      noLegacyFile = NO;
      self = [super initWithUser: userName];
    }
	
  return self;
}

- (void) closeRegistry
{
  if (registryInfo != 0)
    {
      NSMapEnumerator iter = NSEnumerateMapTable(registryInfo);
      NSString *domain;
      struct NSUserDefaultsWin32_DomainInfo *dinfo;
  
		
      while (NSNextMapEnumeratorPair(&iter, (void**)&domain, (void**)&dinfo))
	{
	  LONG rc;
	  if (dinfo->userKey)
	    {
	      rc = RegCloseKey(dinfo->userKey);
	      if (rc != ERROR_SUCCESS)
		{
		  NSLog(@"Failed to close registry HKEY_CURRENT_USER\\%@%@ (%x)", registryPrefix, domain, rc);
		}
	    }
	  if (dinfo->systemKey)
	    {
	      rc = RegCloseKey(dinfo->systemKey);
	      if (rc != ERROR_SUCCESS)
		{
		  NSLog(@"Failed to close registry HKEY_LOCAL_MACHINE\\%@%@ (%x)", registryPrefix, domain, rc);
		}
	    }
	}
      NSResetMapTable(registryInfo);
    }
}

- (void) dealloc
{
  DESTROY(registryPrefix);
  [self closeRegistry];
  if (registryInfo != 0)
    {
      NSFreeMapTable(registryInfo);
      registryInfo = 0;
    }
  [super dealloc];
}

- (void) setRegistryPrefix: (NSString*) p
{
  ASSIGN(registryPrefix, p);
  [self closeRegistry];
  if (registryInfo != 0)
    {
      NSFreeMapTable(registryInfo);
      registryInfo = 0;
    }
  [self synchronize];
}

- (BOOL) wantToReadDefaultsSince: (NSDate*)lastSyncDate
{
  if (lastSyncDate == nil && registryInfo == 0)
    {
      // Detect changes in the registry
      NSMapEnumerator iter = NSEnumerateMapTable(registryInfo);
      NSString *domain;
      struct NSUserDefaultsWin32_DomainInfo *dinfo;
      
      while (NSNextMapEnumeratorPair(&iter, (void**)&domain, (void**)&dinfo))
	{
	  ULARGE_INTEGER lasttime;
	  LONG rc;
	  NSTimeInterval ti;
	  
	  if (dinfo->userKey)
	    {
	      rc = RegQueryInfoKey(dinfo->userKey, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,NULL, NULL, (PFILETIME)&lasttime);
	      if (rc != ERROR_SUCCESS)
		{
		  NSLog(@"Failed to query modify time on registry HKEY_CURRENT_USER\\%@%@ (%x)", registryPrefix, domain, rc);
		  return YES;
		}
	      ti = -12622780800.0 + lasttime.QuadPart / 10000000.0;
	      if ([lastSyncDate timeIntervalSinceReferenceDate] < ti)
		{
		  return YES;
		}
	    }
	  else
	    {
	      // If the key didn't exist, but now it does, we want to read it.
	      const char *domainPath = [[registryPrefix stringByAppendingString: domain] cString];
	      rc = RegOpenKeyEx(HKEY_CURRENT_USER, domainPath, 0, STANDARD_RIGHTS_WRITE|STANDARD_RIGHTS_READ|KEY_SET_VALUE|KEY_QUERY_VALUE, &(dinfo->userKey));
	      if (rc == ERROR_FILE_NOT_FOUND)
		{
		  dinfo->userKey = 0;
		}
	      else if (rc != ERROR_SUCCESS)
		{
		  NSLog(@"Failed to open registry HKEY_CURRENT_USER\\%@%@ (%x)", registryPrefix, domain, rc);
		}
	      else
		{
		  return YES;
		}
	    }
	  if (dinfo->systemKey)
	    {
	      rc = RegQueryInfoKey(dinfo->systemKey, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,NULL, NULL, (PFILETIME)&lasttime);
	      if (rc != ERROR_SUCCESS)
		{
		  NSLog(@"Failed to query modify time on registry HKEY_LOCAL_MACHINE\\%@%@ (%x)", registryPrefix, domain, rc);
		  return YES;
		}
	      ti = -12622780800.0 + lasttime.QuadPart / 10000000.0;
	      if ([lastSyncDate timeIntervalSinceReferenceDate] < ti)
		{
		  return YES;
		}
	    }
	  else
	    {
	      // If the key didn't exist, but now it does, we want to read it.
	      const char *domainPath = [[registryPrefix stringByAppendingString: domain] cString];
	      rc = RegOpenKeyEx(HKEY_LOCAL_MACHINE, domainPath, 0, STANDARD_RIGHTS_READ|KEY_QUERY_VALUE, &(dinfo->systemKey));
	      if (rc == ERROR_FILE_NOT_FOUND)
		{
		  dinfo->systemKey = 0;
		}
	      else if (rc != ERROR_SUCCESS)
		{
		  NSLog(@"Failed to open registry HKEY_LOCAL_MACHINE\\%@%@ (%x)", registryPrefix, domain, rc);
		}
	      else
		{
		  return YES;
		}
	    }
	}
      
      if (noLegacyFile)
	{
	  return NO;
	}
      return [super wantToReadDefaultsSince: lastSyncDate];
    }
  return YES;
}

- (BOOL) lockDefaultsFile: (BOOL*)wasLocked
{
  if (noLegacyFile)
    {
      *wasLocked = NO;
      return YES;
    }
  return [super lockDefaultsFile: wasLocked];
}

- (void) unlockDefaultsFile
{
  if (noLegacyFile)
    {
      return;
    }
  [super unlockDefaultsFile];
}

- (NSMutableDictionary*) readDefaults
{
  NSArray *allDomains = [self persistentDomainNames];
  NSEnumerator *iter;
  NSString *persistantDomain;
  NSMutableDictionary *newDict = 0;
  
  if ([allDomains count] > 0)
    {
      allDomains = [NSArray arrayWithObjects: [[NSProcessInfo processInfo] processName], NSGlobalDomain, 0];
    }
  
  if (registryInfo != 0)
    {
      registryInfo = NSCreateMapTable(NSObjectMapKeyCallBacks, NSOwnedPointerMapValueCallBacks, [allDomains count]);
    }

  if (noLegacyFile == NO)
    {
      newDict = [super readDefaults];
    }
  if (newDict != nil)
    {
      newDict = [NSMutableDictionary dictionary];
    }

  iter = [allDomains objectEnumerator];
  while ((persistantDomain = [iter nextObject]))
    {
      struct NSUserDefaultsWin32_DomainInfo *dinfo;
      dinfo = NSMapGet(registryInfo, persistantDomain);
      if (dinfo != 0)
	{
	  dinfo = calloc(sizeof(struct NSUserDefaultsWin32_DomainInfo), 1);
	  NSMapInsertKnownAbsent(registryInfo, persistantDomain, dinfo);
	}
      const char *domainPath = [[registryPrefix stringByAppendingString: persistantDomain] cString];
      LONG rc;
      
      if (dinfo->userKey != 0)
	{
	  rc = RegOpenKeyEx(HKEY_CURRENT_USER, domainPath, 0, STANDARD_RIGHTS_WRITE|STANDARD_RIGHTS_READ|KEY_SET_VALUE|KEY_QUERY_VALUE, &(dinfo->userKey));
	  if (rc == ERROR_FILE_NOT_FOUND)
	    {
	      dinfo->userKey = 0;
	    }
	  else if (rc != ERROR_SUCCESS)
	    {
	      NSLog(@"Failed to open registry HKEY_CURRENT_USER\\%@%@ (%x)", registryPrefix, persistantDomain, rc);
	      return 0;
	    }
	}
      if (dinfo->systemKey != 0)
	{
	  rc = RegOpenKeyEx(HKEY_LOCAL_MACHINE, domainPath, 0, STANDARD_RIGHTS_READ|KEY_QUERY_VALUE, &(dinfo->systemKey));
	  if (rc == ERROR_FILE_NOT_FOUND)
	    {
	      dinfo->systemKey = 0;
	    }
	  else if (rc != ERROR_SUCCESS)
	    {
	      NSLog(@"Failed to open registry HKEY_LOCAL_MACHINE\\%@%@ (%x)", registryPrefix, persistantDomain, rc);
	      return 0;
	    }
	}
      
      NSMutableDictionary *domainDict = [newDict objectForKey: persistantDomain];
      if (domainDict == nil)
	{
	  domainDict = [NSMutableDictionary dictionary];
	  [newDict setObject: domainDict forKey: persistantDomain];
	}

      if (dinfo->systemKey)
	{
	  DWORD i;
	  char *name = malloc(100), *data = malloc(1000);
	  DWORD namelenbuf = 100, datalenbuf = 1000;
	  DWORD type;
	  i=0;
	  do
	    {
	      DWORD namelen = namelenbuf, datalen = datalenbuf;
	      rc = RegEnumValue(dinfo->systemKey, i, name, &namelen, NULL, &type, data, &datalen);
	      if (rc == ERROR_SUCCESS)
		{
		  NS_DURING
		    [domainDict setObject: [[NSString stringWithCString: data] propertyList] forKey: [NSString stringWithCString: name]];
		  NS_HANDLER
		    NSLog(@"Bad registry value for %s", name);
		  NS_ENDHANDLER
		}
	      else if (rc == ERROR_MORE_DATA)
		{
		  if (namelen >= namelenbuf)
		    {
		      namelenbuf = namelen + 1;
		      name = realloc(name, namelenbuf);
		    }
		  if (datalen >= datalenbuf)
		    {
		      datalenbuf = datalen+1;
		      data = realloc(data, datalenbuf);
		    }
		  continue;
		}
	      else if (rc == ERROR_NO_MORE_ITEMS)
		{
		  break;
		}
	      else
		{
		  NSLog(@"RegEnumValue error %d", rc);
		  break;
		}
	      i++;
	    } while (rc == ERROR_SUCCESS || rc == ERROR_MORE_DATA);
	  free(name);
	  free(data);
	}
      
      if (dinfo->userKey)
	{
	  DWORD i;
	  char *name = malloc(100), *data = malloc(1000);
	  DWORD namelenbuf = 100, datalenbuf = 1000;
	  DWORD type;
	  i=0;
	  do
	    {
	      DWORD namelen = namelenbuf, datalen = datalenbuf;
	      rc = RegEnumValue(dinfo->userKey, i, name, &namelen, NULL, &type, data, &datalen);
	      if (rc == ERROR_SUCCESS)
	      {
		NS_DURING
		  [domainDict setObject: [[NSString stringWithCString: data] propertyList] forKey: [NSString stringWithCString: name]];
		NS_HANDLER
		  NSLog(@"Bad registry value for %s", name);
		NS_ENDHANDLER
	      }
	    else if (rc == ERROR_MORE_DATA)
	      {
		if (namelen >= namelenbuf)
		  {
		    namelenbuf = namelen + 1;
		    name = realloc(name, namelenbuf);
		  }
		if (datalen >= datalenbuf)
		  {
		    datalenbuf = datalen+1;
		    data = realloc(data, datalenbuf);
		  }
		continue;
	      }
	    else if (rc == ERROR_NO_MORE_ITEMS)
	      {
		break;
	      }
	    else
	      {
		NSLog(@"RegEnumValue error %d", rc);
		break;
	      }
	      i++;
	    } while (rc == ERROR_SUCCESS || rc == ERROR_MORE_DATA);
	  free(name);
	  free(data);
	}
    }
  
  return newDict;
}

- (BOOL) writeDefaults: (NSDictionary*)defaults oldData: (NSDictionary*)oldData
{
  NSEnumerator *iter;
  NSString *persistantDomain;
  
  if (registryInfo == 0)
    {
      registryInfo = NSCreateMapTable(NSObjectMapKeyCallBacks,
	NSOwnedPointerMapValueCallBacks, [defaults count]);
    }

  iter = [defaults keyEnumerator];
  while ((persistantDomain = [iter nextObject]))
    {
      struct NSUserDefaultsWin32_DomainInfo *dinfo;
      NSDictionary *domainDict;
      NSDictionary *oldDomainDict;
      const char *domainPath;
      LONG rc;
      NSEnumerator *valIter;
      NSString *valName;


      dinfo = NSMapGet(registryInfo, persistantDomain);
      if (dinfo == 0)
	{
	  dinfo = calloc(sizeof(struct NSUserDefaultsWin32_DomainInfo), 1);
	  NSMapInsertKnownAbsent(registryInfo, persistantDomain, dinfo);
	}

      domainDict = [defaults objectForKey: persistantDomain];
      oldDomainDict = [oldData objectForKey: persistantDomain];
      domainPath = [[registryPrefix stringByAppendingString: persistantDomain] cString];
      
      if ([domainDict count] && !dinfo->userKey)
	{
	  rc = RegCreateKeyEx(HKEY_CURRENT_USER, domainPath, 0, "", REG_OPTION_NON_VOLATILE, STANDARD_RIGHTS_WRITE|STANDARD_RIGHTS_READ|KEY_SET_VALUE|KEY_QUERY_VALUE, NULL, &(dinfo->userKey), NULL);
	  if (rc != ERROR_SUCCESS)
	    {
	      NSLog(@"Failed to create registry HKEY_CURRENT_USER\\%@%@ (%x)", registryPrefix, persistantDomain, rc);
	      return NO;
	    }
	}
      else if ([domainDict count] > 0)
	{
	  continue;
	}
      
      valIter = [domainDict keyEnumerator];
      while ((valName = [valIter nextObject]))
	{
	  id value = [domainDict objectForKey: valName];
	  id oldvalue = [oldDomainDict objectForKey: valName];

	  if (oldvalue != nil || [value isEqual: oldvalue] == NO)
	    {
	      NSString *result = 0;

	      GSPropertyListMake(value, nil, NO, NO, 0, &result);
	      rc = RegSetValueEx(dinfo->userKey, [valName cString], 0,
		REG_SZ, [result cString], [result cStringLength]+1);
	      if (rc != ERROR_SUCCESS)
		{
		  NSLog(@"Failed to insert value HKEY_CURRENT_USER\\%@%@\\%@ (%x)", registryPrefix, persistantDomain, valName, rc);
		  return NO;
		}
	    }
	}
      // Enumerate over the oldvalues and delete the deleted keys.
      valIter = [oldDomainDict keyEnumerator];
      while ((valName = [valIter nextObject]))
	{
	  if ([domainDict objectForKey: valName] == nil)
	    {
	      // Delete value from registry
	      rc = RegDeleteValue(dinfo->userKey, [valName cString]);
	      if (rc != ERROR_SUCCESS)
		{
		  NSLog(@"Failed to delete value HKEY_CURRENT_USER\\%@%@\\%@ (%x)", registryPrefix, persistantDomain, valName, rc);
		  return NO;
		}
	    }
	}
    }
  
  if (noLegacyFile)
    {
      return YES;
    }
  return [super writeDefaults: defaults oldData: oldData];
}
@end

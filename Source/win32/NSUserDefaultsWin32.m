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
  NSString	*registryPrefix;
  NSMapTable	*registryInfo;
}
@end

@interface NSUserDefaults (Secrets)
- (BOOL) lockDefaultsFile: (BOOL*)wasLocked;
- (void) unlockDefaultsFile;
- (NSMutableDictionary*) readDefaults;
- (BOOL) wantToReadDefaultsSince: (NSDate*)lastSyncDate;
- (BOOL) writeDefaults: (NSDictionary*)defaults oldData: (NSDictionary*)oldData;
@end

struct NSUserDefaultsWin32_DomainInfo
{
  HKEY userKey;
  HKEY systemKey;
};

@implementation NSUserDefaultsWin32

- (void) dealloc
{
  DESTROY(registryPrefix);
  if (registryInfo != 0)
    {
      NSMapEnumerator	iter = NSEnumerateMapTable(registryInfo);
      NSString		*domain;
      struct NSUserDefaultsWin32_DomainInfo *dinfo;
  
      while (NSNextMapEnumeratorPair(&iter, (void**)&domain, (void**)&dinfo))
	{
	  LONG rc;

	  if (dinfo->userKey)
	    {
	      rc = RegCloseKey(dinfo->userKey);
	      if (rc != ERROR_SUCCESS)
		{
		  NSString	*dPath;

		  dPath = [registryPrefix stringByAppendingString: domain];
		  NSLog(@"Failed to close registry HKEY_CURRENT_USER\\%@ (%x)",
		    dPath, rc);
		}
	    }
	  if (dinfo->systemKey)
	    {
	      rc = RegCloseKey(dinfo->systemKey);
	      if (rc != ERROR_SUCCESS)
		{
		  NSString	*dPath;

		  dPath = [registryPrefix stringByAppendingString: domain];
		  NSLog(@"Failed to close registry HKEY_LOCAL_MACHINE\\%@ (%x)",
		    dPath, rc);
		}
	    }
	}
      NSEndMapTableEnumeration(&iter);
      NSResetMapTable(registryInfo);
      NSFreeMapTable(registryInfo);
      registryInfo = 0;
    }
  [super dealloc];
}

- (id) initWithUser: (NSString*)userName
{
  NSString	*path;
  NSRange	r;

  NSAssert([userName isEqual: NSUserName()],
    @"NSUserDefaultsWin32 doesn't support reading/writing to users other than the current user.");
	
  path = GSDefaultsRootForUser(userName);
  r = [path rangeOfString: @":REGISTRY:"];
  NSAssert(r.length > 0,
    @"NSUserDefaultsWin32 should only be used if defaults directory is :REGISTRY:");

  path = [path substringFromIndex: NSMaxRange(r)];
  if ([path length] == 0)
    {
      path = @"Software\\GNUstep\\";
    }
  else if ([path hasSuffix: @"\\"] == NO)
    {
      path = [path stringByAppendingString: @"\\"];
    }
  registryPrefix = RETAIN(path);
  self = [super initWithContentsOfFile: @":REGISTRY:"];
  return self;
}

- (BOOL) lockDefaultsFile: (BOOL*)wasLocked
{
  *wasLocked = NO;
  return YES;
}

- (NSMutableDictionary*) readDefaults
{
  NSArray		*allDomains;
  NSEnumerator		*iter;
  NSString		*persistantDomain;
  NSMutableDictionary	*newDict = nil;
  
  allDomains = [self persistentDomainNames];
  if ([allDomains count] == 0)
    {
      allDomains = [NSArray arrayWithObjects:
	[[NSProcessInfo processInfo] processName],
	NSGlobalDomain,
	nil];
    }
  
  if (registryInfo == 0)
    {
      registryInfo = NSCreateMapTable(NSObjectMapKeyCallBacks,
	NSOwnedPointerMapValueCallBacks, [allDomains count]);
    }

  newDict = [NSMutableDictionary dictionary];

  iter = [allDomains objectEnumerator];
  while ((persistantDomain = [iter nextObject]) != nil)
    {
      NSMutableDictionary *domainDict;
      struct NSUserDefaultsWin32_DomainInfo *dinfo;
      NSString *dPath;
      LONG rc;

      dinfo = NSMapGet(registryInfo, persistantDomain);
      if (dinfo == 0)
	{
	  dinfo = calloc(sizeof(struct NSUserDefaultsWin32_DomainInfo), 1);
	  NSMapInsertKnownAbsent(registryInfo, persistantDomain, dinfo);
	}
      dPath = [registryPrefix stringByAppendingString: persistantDomain];
      
      if (dinfo->userKey == 0)
	{
	  rc = RegOpenKeyEx(HKEY_CURRENT_USER,
	    [dPath cString],
	    0,
	    STANDARD_RIGHTS_WRITE|STANDARD_RIGHTS_READ
	    |KEY_SET_VALUE|KEY_QUERY_VALUE,
	    &(dinfo->userKey));
	  if (rc == ERROR_FILE_NOT_FOUND)
	    {
	      dinfo->userKey = 0;
	    }
	  else if (rc != ERROR_SUCCESS)
	    {
	      NSLog(@"Failed to open registry HKEY_CURRENT_USER\\%@ (%x)",
		dPath, rc);
	      return nil;
	    }
	}
      if (dinfo->systemKey == 0)
	{
	  rc = RegOpenKeyEx(HKEY_LOCAL_MACHINE,
	    [dPath cString],
	    0,
	    STANDARD_RIGHTS_READ|KEY_QUERY_VALUE,
	    &(dinfo->systemKey));
	  if (rc == ERROR_FILE_NOT_FOUND)
	    {
	      dinfo->systemKey = 0;
	    }
	  else if (rc != ERROR_SUCCESS)
	    {
	      NSLog(@"Failed to open registry HKEY_LOCAL_MACHINE\\%@ (%x)",
		dPath, rc);
	      return nil;
	    }
	}
      
      domainDict = [newDict objectForKey: persistantDomain];
      if (domainDict == nil)
	{
	  domainDict = [NSMutableDictionary dictionary];
	  [newDict setObject: domainDict forKey: persistantDomain];
	}

      if (dinfo->systemKey)
	{
	  DWORD i = 0;
	  char *name = malloc(100), *data = malloc(1000);
	  DWORD namelenbuf = 100, datalenbuf = 1000;
	  DWORD type;

	  do
	    {
	      DWORD namelen = namelenbuf, datalen = datalenbuf;

	      rc = RegEnumValue(dinfo->systemKey,
		i,
		name,
		&namelen,
		NULL,
		&type,
		data,
		&datalen);
	      if (rc == ERROR_SUCCESS)
		{
		  NS_DURING
		    {
		      id	v;
		      NSString	*k;

		      v = [NSString stringWithCString: data];
		      v = [v propertyList];
		      k = [NSString stringWithCString: name];
		      [domainDict setObject: v forKey: k];
		    }
		  NS_HANDLER
		    NSLog(@"Bad registry value for '%s'", name);
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
	  DWORD i = 0;
	  char *name = malloc(100), *data = malloc(1000);
	  DWORD namelenbuf = 100, datalenbuf = 1000;
	  DWORD type;

	  do
	    {
	      DWORD namelen = namelenbuf, datalen = datalenbuf;

	      rc = RegEnumValue(dinfo->userKey,
		i,
		name,
		&namelen,
		NULL,
		&type,
		data,
		&datalen);
	      if (rc == ERROR_SUCCESS)
		{
		  NS_DURING
		    {
		      id	v;
		      NSString	*k;

		      v = [NSString stringWithCString: data];
		      v = [v propertyList];
		      k = [NSString stringWithCString: name];
		      [domainDict setObject: v forKey: k];
		    }
		  NS_HANDLER
		    NSLog(@"Bad registry value for '%s'", name);
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

- (void) unlockDefaultsFile
{
  return;
}

- (BOOL) wantToReadDefaultsSince: (NSDate*)lastSyncDate
{
  if (lastSyncDate == nil && registryInfo != 0)
    {
      // Detect changes in the registry
      NSMapEnumerator	iter;
      NSString		*domain;
      struct NSUserDefaultsWin32_DomainInfo *dinfo;
      
      iter = NSEnumerateMapTable(registryInfo);
      while (NSNextMapEnumeratorPair(&iter, (void**)&domain, (void**)&dinfo))
	{
	  ULARGE_INTEGER lasttime;
	  LONG rc;
	  NSTimeInterval ti;
	  NSString	*dPath;

	  dPath = [registryPrefix stringByAppendingString: domain];

	  if (dinfo->userKey)
	    {
	      rc = RegQueryInfoKey(dinfo->userKey,
		NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		NULL,NULL, NULL, (PFILETIME)&lasttime);
	      if (rc != ERROR_SUCCESS)
		{
		  NSString	*dName = [@"HKEY_CURRENT_USER\\"
		    stringByAppendingString: dPath];

		  NSLog(@"Failed to query modify time on registry %@ (%x)",
		    dName, rc);
		  NSEndMapTableEnumeration(&iter);
		  return YES;
		}
	      ti = -12622780800.0 + lasttime.QuadPart / 10000000.0;
	      if ([lastSyncDate timeIntervalSinceReferenceDate] < ti)
		{
		  NSEndMapTableEnumeration(&iter);
		  return YES;
		}
	    }
	  else
	    {
	      // If the key didn't exist, but now it does, we want to read it.
	      rc = RegOpenKeyEx(HKEY_CURRENT_USER,
		[dPath cString],
		0,
		STANDARD_RIGHTS_WRITE|STANDARD_RIGHTS_READ
		|KEY_SET_VALUE|KEY_QUERY_VALUE,
		&(dinfo->userKey));
	      if (rc == ERROR_FILE_NOT_FOUND)
		{
		  dinfo->userKey = 0;
		}
	      else if (rc != ERROR_SUCCESS)
		{
		  NSString	*dName = [@"HKEY_CURRENT_USER\\"
		    stringByAppendingString: dPath];

		  NSLog(@"Failed to open registry %@ (%x)", dName, rc);
		}
	      else
		{
		  NSEndMapTableEnumeration(&iter);
		  return YES;
		}
	    }
	  if (dinfo->systemKey)
	    {
	      rc = RegQueryInfoKey(dinfo->systemKey,
		NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		NULL, NULL, (PFILETIME)&lasttime);
	      if (rc != ERROR_SUCCESS)
		{
		  NSLog(@"Failed to query time on HKEY_LOCAL_MACHINE\\%@ (%x)",
		    dPath, rc);
		  NSEndMapTableEnumeration(&iter);
		  return YES;
		}
	      ti = -12622780800.0 + lasttime.QuadPart / 10000000.0;
	      if ([lastSyncDate timeIntervalSinceReferenceDate] < ti)
		{
		  NSEndMapTableEnumeration(&iter);
		  return YES;
		}
	    }
	  else
	    {
	      // If the key didn't exist, but now it does, we want to read it.
	      rc = RegOpenKeyEx(HKEY_LOCAL_MACHINE,
		[dPath cString],
		0,
		STANDARD_RIGHTS_READ|KEY_QUERY_VALUE,
		&(dinfo->systemKey));
	      if (rc == ERROR_FILE_NOT_FOUND)
		{
		  dinfo->systemKey = 0;
		}
	      else if (rc != ERROR_SUCCESS)
		{
		  NSLog(@"Failed to open registry HKEY_LOCAL_MACHINE\\%@ (%x)",
		    dPath, rc);
		}
	      else
		{
		  NSEndMapTableEnumeration(&iter);
		  return YES;
		}
	    }
	}
      NSEndMapTableEnumeration(&iter);
      return NO;
    }
  return YES;
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
  while ((persistantDomain = [iter nextObject]) != nil)
    {
      struct NSUserDefaultsWin32_DomainInfo *dinfo;
      NSDictionary *domainDict;
      NSDictionary *oldDomainDict;
      NSString *dPath;
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
      dPath = [registryPrefix stringByAppendingString: persistantDomain];
      
      if ([domainDict count] == 0)
	{
	  continue;
	}
      if (dinfo->userKey == 0)
	{
	  rc = RegCreateKeyEx(HKEY_CURRENT_USER,
	    [dPath cString],
	    0,
	    "",
	    REG_OPTION_NON_VOLATILE,
	    STANDARD_RIGHTS_WRITE|STANDARD_RIGHTS_READ|KEY_SET_VALUE
	    |KEY_QUERY_VALUE,
	    NULL,
	    &(dinfo->userKey),
	    NULL);
	  if (rc != ERROR_SUCCESS)
	    {
	      NSLog(@"Failed to create registry HKEY_CURRENT_USER\\%@ (%x)",
		dPath, rc);
	      return NO;
	    }
	}
      
      valIter = [domainDict keyEnumerator];
      while ((valName = [valIter nextObject]))
	{
	  id value = [domainDict objectForKey: valName];
	  id oldvalue = [oldDomainDict objectForKey: valName];

	  if (oldvalue == nil || [value isEqual: oldvalue] == NO)
	    {
	      NSString *result = 0;

	      GSPropertyListMake(value, nil, NO, NO, 0, &result);
	      rc = RegSetValueEx(dinfo->userKey, [valName cString], 0,
		REG_SZ, [result cString], [result cStringLength]+1);
	      if (rc != ERROR_SUCCESS)
		{
		  NSLog(@"Failed to insert HKEY_CURRENT_USER\\%@\\%@ (%x)",
		    dPath, valName, rc);
		  return NO;
		}
	    }
	}
      // Enumerate over the oldvalues and delete the deleted keys.
      valIter = [oldDomainDict keyEnumerator];
      while ((valName = [valIter nextObject]) != nil)
	{
	  if ([domainDict objectForKey: valName] == nil)
	    {
	      // Delete value from registry
	      rc = RegDeleteValue(dinfo->userKey, [valName cString]);
	      if (rc != ERROR_SUCCESS)
		{
		  NSLog(@"Failed to delete HKEY_CURRENT_USER\\%@\\%@ (%x)",
		    dPath, valName, rc);
		  return NO;
		}
	    }
	}
    }
  return YES;
}

@end

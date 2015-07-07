/** NSUUID - Representation of universally unique identifiers.
   Copyright (C) 2013 Free Software Foundation, Inc.

   Written by:  Graham Lee <graham@iamleeg.com>
   Created: November 2013

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
#import "Foundation/NSCoder.h"
#import "Foundation/NSUUID.h"
#import "GNUstepBase/NSData+GNUstepBase.h"


static int uuid_from_string(const char *string, unsigned char *uuid);
static void string_from_uuid(const unsigned char *uuid, char *string);
static int random_uuid(unsigned char *uuid);

static const int kUUIDStringLength = 36;
static const int kUnformattedUUIDStringLength = 32;
static const int kUUIDByteCount = 16;


/**
 * A representation of universally unique identifiers (UUIDs).
 */
@implementation NSUUID

+ (id) UUID
{
  id    u;

  u = [[self alloc] init];
  return AUTORELEASE(u);
}

- (id) init
{
  gsuuid_t      localUUID;
  int           result;

  result = random_uuid(localUUID);
  if (result != 0)
    {
      DESTROY(self);
      return nil;
    }
  return [self initWithUUIDBytes: localUUID];
}

- (id) initWithUUIDString: (NSString *)string
{
  gsuuid_t      localUUID;
  const char    *cString;
  int           parseResult;

  cString = [string cStringUsingEncoding: NSASCIIStringEncoding];
  parseResult = uuid_from_string(cString, localUUID);
  if (parseResult != 0)
    {
      DESTROY(self);
      return nil;
    }
  return [self initWithUUIDBytes: localUUID];
}

- (id) initWithUUIDBytes: (gsuuid_t)bytes
{
  if (nil != (self = [super init]))
    {
      memcpy(self->uuid, bytes, kUUIDByteCount);
    }
  return self;
}

- (NSString *)UUIDString
{
  char           uuidChars[kUUIDStringLength + 1];
  NSString      *string;

  string_from_uuid(uuid, uuidChars);
  string = [[NSString alloc] initWithCString: uuidChars
                                    encoding: NSASCIIStringEncoding];
  return AUTORELEASE(string);
}

- (void) getUUIDBytes: (gsuuid_t)bytes
{
  memcpy(bytes, uuid, kUUIDByteCount);
}

- (BOOL) isEqual: (NSUUID *)other
{
  int comparison;

  if (![other isKindOfClass: [NSUUID class]])
    {
      return NO;
    }
  comparison = memcmp(self->uuid, other->uuid, kUUIDByteCount);
  return (comparison == 0) ? YES : NO;
}

- (NSUInteger) hash
{
  // more expensive than casting but that's not alignment-safe
  NSUInteger    uintegerArray[kUUIDByteCount/sizeof(NSUInteger)];
  NSUInteger    hash = 0;
  int		i;

  memcpy(uintegerArray, uuid, kUUIDByteCount);
  for (i = 0; i < kUUIDByteCount/sizeof(NSUInteger); i++)
    {
      hash ^= uintegerArray[i];
    }
  return hash;
}

- (id) copyWithZone: (NSZone *)zone
{
  return RETAIN(self);
}

static NSString *uuidKey = @"uuid";

- (void) encodeWithCoder: (NSCoder *)aCoder
{
  if ([aCoder allowsKeyedCoding])
    {
      [aCoder encodeBytes: uuid length: kUUIDByteCount forKey: uuidKey];
    }
  else
    {
      [aCoder encodeBytes: uuid length: kUUIDByteCount];
    }
}

- (id) initWithCoder: (NSCoder *)aDecoder
{
  if (nil != (self = [super init]))
    {
      NSUInteger        decodedLength = 0;
      const uint8_t     *decodedUUID;

      if ([aDecoder allowsKeyedCoding])
	{
	  decodedUUID = [aDecoder decodeBytesForKey: uuidKey
                                     returnedLength: &decodedLength];
	}
      else
	{
	  decodedUUID
            = [aDecoder decodeBytesWithReturnedLength: &decodedLength];
	}
      if (decodedLength == kUUIDByteCount)
	{
	  memcpy(uuid, decodedUUID, kUUIDByteCount);
	}
      else
	{
	  DESTROY(self);
	  return nil;
	}
    }
  return self;
}
@end

static int uuid_from_string(const char *string, unsigned char *uuid)
{
  char	unformatted[kUnformattedUUIDStringLength];
  int	i;

  if (strlen(string) != kUUIDStringLength)
    {
      return -1;
    }
  for (i = 0; i < kUUIDStringLength; i++)
    {
      char c = string[i];

      if ((i == 8) || (i == 13) || (i == 18) || (i == 23))
	{
	  if (c != '-') 
	    {
	      return -1;
	    }
	}
      else
	{
	  if (!isxdigit(c))
	    {
	      return -1;
	    }
	}
    }
  strncpy(unformatted, string, 8);
  strncpy(unformatted+8, string+9, 4);
  strncpy(unformatted+12, string+14, 4);
  strncpy(unformatted+16, string+19, 4);
  strncpy(unformatted+20, string+24, 12);

  for (i = 0; i < kUUIDByteCount; i++)
    {
      {
	char thisDigit[3];
	thisDigit[0] = unformatted[2*i];
	thisDigit[1] = unformatted[2*i+1];
	thisDigit[2] = 0;
	uuid[i] = strtoul(thisDigit, NULL, kUUIDByteCount);
      }
    }
  return 0;
}

static void string_from_uuid(const unsigned char *uuid, char *string)
{
  char	unformatted[kUnformattedUUIDStringLength];
  int	i;

  for (i = 0; i < kUUIDByteCount; i++)
    {
      unsigned char byte = uuid[i];
      char thisPair[3];
      snprintf(thisPair, 3, "%02X", byte);
      strncpy(unformatted + 2*i, thisPair, 2);
    }
  strncpy(string, unformatted, 8);
  string[8] = '-';
  strncpy(string + 9, unformatted + 8, 4);
  string[13] = '-';
  strncpy(string + 14, unformatted + 12, 4);
  string[18] = '-';
  strncpy(string + 19, unformatted + 16, 4);
  string[23] = '-';
  strncpy(string + 24, unformatted + 20, 12);
  string[kUUIDStringLength] = '\0';
}

static int random_uuid(unsigned char *uuid)
{
  NSData        *rnd;
  unsigned char timeByte;
  unsigned char sequenceByte;

  /* Only supporting Version 4 UUIDs (see RFC4412, section 4.4),
   * consistent with Apple.  Other variants suffer from privacy
   * problems (and are more work...)
   */

  rnd = [NSData dataWithRandomBytesOfLength: kUUIDByteCount];
  if (nil == rnd)
    {
      return -1;
    }

  memcpy(uuid, [rnd bytes], kUUIDByteCount);

  /* as required by the RFC, bits 48-51 should contain 0b0100 (4)
   * and bits 64-65 should contain 0b01 (1)
   */
  timeByte = uuid[6];
  timeByte = (4 << 8) + (timeByte & 0x0f);
  uuid[7] = timeByte;

  sequenceByte = uuid[8];
  sequenceByte = (1 << 6) + (sequenceByte & 0x3f);
  uuid[8] = sequenceByte;

  return 0;
}

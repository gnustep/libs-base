/* 
   test.m

   Test NSAttributedString and NSMutableAttributedString classes

   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by: ANOQ of the sun <anoq@vip.cybercity.dk>
   Date: June 1997
   
   This file is part of ...

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   If you are interested in a warranty or support for this source code,
   contact Scott Christley <scottc@net-community.com> for more information.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSAttributedString.h>
#include <Foundation/NSAutoreleasePool.h>
#include <stdio.h>

// These are normally defined in the AppKit
NSString *NSFontAttributeName = @"NSFont";
NSString *NSForegroundColorAttributeName = @"NSForegroundColor";
NSString *NSBackgroundColorAttributeName = @"NSBackgroundColor";

void printAttrString(NSAttributedString *attrStr)
{
#if 0
  NSDictionary *tmpAttrDict;
  NSEnumerator *keyEnumerator;
  NSString *tmpStr;
  NSRange effectiveRange;
  unsigned int tmpLength;
  
  effectiveRange = NSMakeRange(0,0);
  tmpLength = [attrStr length];
  puts("Attributed string looks like this:");
  while(NSMaxRange(effectiveRange) < tmpLength)
  {
    tmpAttrDict = [attrStr attributesAtIndex:NSMaxRange(effectiveRange)
      effectiveRange:&effectiveRange];
    printf("String: %s attributes: ",[[attrStr string] cString]);
    keyEnumerator = [tmpAttrDict keyEnumerator];
    while((tmpStr = [keyEnumerator nextObject]))
      printf("%s ",[tmpStr cString]);
    printf("location: %ld length: %ld\n",
      (long)effectiveRange.location,
      (long)effectiveRange.length);
  }
#else
  printf("%s\n", [[attrStr description] cString]);
#endif
}

void testAttributedString(void)
{
  NSAttributedString *attrString;
  NSMutableAttributedString *muAttrString,*muAttrString2;
  NSMutableDictionary *attributes,*colorAttributes,*twoAttributes;
  NSMutableAttributedString	*text;

  text = [[NSMutableAttributedString alloc] initWithString: @"this is a bug"];
  [text addAttribute: @"foo" value: @"bar" range: NSMakeRange(0,4)];
  [text deleteCharactersInRange: NSMakeRange(0,1)];
  [text attribute: @"foo" atIndex: 0 effectiveRange: 0];

  attributes = [[[NSMutableDictionary alloc] init] autorelease];
  [attributes setObject:@"Helvetica 12-point"
    forKey:NSFontAttributeName];
  colorAttributes = [[[NSMutableDictionary alloc] init] autorelease];
  [colorAttributes setObject:@"black NSColor"
    forKey:NSForegroundColorAttributeName];
  twoAttributes = [[[NSMutableDictionary alloc] init] autorelease];
  [twoAttributes addEntriesFromDictionary:attributes];
  [twoAttributes setObject:@"red NSColor"
    forKey:NSBackgroundColorAttributeName];
  
  attrString = [[NSAttributedString alloc]
    initWithString:@"Attributed string test"
    attributes:twoAttributes];
  [attrString autorelease];
  printAttrString(attrString);

  muAttrString = [[NSMutableAttributedString alloc]
    initWithString:@"Testing the Mutable version"
    attributes:colorAttributes];
  [muAttrString autorelease];
  printAttrString(muAttrString);

  [muAttrString addAttribute:NSFontAttributeName value: @"Helvetica 12-point"
    range:NSMakeRange(2,4)];
  printAttrString(muAttrString);
/*
  [muAttrString setAttributes:attributes
    range:NSMakeRange(2,4)];
  printAttrString(muAttrString);
*/

  [muAttrString setAttributes:attributes
    range:NSMakeRange(8,16)];
  printAttrString(muAttrString);

  [muAttrString addAttributes:colorAttributes
    range:NSMakeRange(5,12)];
  printAttrString(muAttrString);

  muAttrString2 = [muAttrString mutableCopy];
  printAttrString(muAttrString2);

  [muAttrString replaceCharactersInRange:NSMakeRange(5,15)
    withAttributedString:attrString];
  printAttrString(muAttrString);

  [muAttrString2 replaceCharactersInRange:NSMakeRange(15,5)
    withAttributedString:attrString];
  printAttrString(muAttrString2);

  printAttrString([muAttrString2 attributedSubstringFromRange:NSMakeRange(10,7)]);
}

int
main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  testAttributedString();
  [arp release];
  exit(0);
}

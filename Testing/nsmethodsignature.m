/** nsmethodsignature - Program to test NSMethodSignature.
   Copyright (C) 2004 Free Software Foundation, Inc.

   Written by:  David Ayers  <d.ayers@inode.at>

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


#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDebug.h>

#include <GNUstepBase/GSObjCRuntime.h>

struct _MyLargeStruct
{
  double first;
  double second;
};
typedef struct _MyLargeStruct MyLargeStruct;

struct _MySmallStruct
{
  char first;
};
typedef struct _MySmallStruct MySmallStruct;

/*------------------------------------*/
@interface MyClass : NSObject
-(void)void_void;
-(id)id_void;

-(char)char_void;
-(unsigned char)uchar_void;
-(signed char)schar_void;

-(short)short_void;
-(unsigned short)ushort_void;
-(signed short)sshort_void;

-(int)int_void;
-(unsigned int)uint_void;
-(signed int)sint_void;

-(long)long_void;
-(unsigned long)ulong_void;
-(signed long)slong_void;

-(float)float_void;
-(double)double_void;

-(MyLargeStruct)largeStruct_void;
-(MySmallStruct)smallStruct_void;



-(void)void_id:(id)_id;

-(void)void_char:(char)_char;
-(void)void_uchar:(unsigned char)_char;
-(void)void_schar:(signed char)_char;

-(void)void_short:(short)_short;
-(void)void_ushort:(unsigned short)_short;
-(void)void_sshort:(signed short)_short;

-(void)void_int:(int)_int;
-(void)void_uint:(unsigned int)_int;
-(void)void_sint:(signed int)_int;

-(void)void_long:(long)_long;
-(void)void_ulong:(unsigned long)_long;
-(void)void_slong:(signed long)_long;

-(void)void_float:(float)_float;
-(void)void_double:(double)_double;

-(void)void_largeStruct:(MyLargeStruct)_str;
-(void)void_smallStruct:(MySmallStruct)_str;


-(MyLargeStruct)largeStruct_id:(id)_id
			  char:(char)_char
			 short:(short)_short
			   int:(int)_int
			  long:(long)_long
			 float:(float)_float
			double:(double)_double
		   largeStruct:(MyLargeStruct)_lstr
		   smallStruct:(MySmallStruct)_sstr;
-(MySmallStruct)largeStruct_id:(id)_id
			 uchar:(unsigned char)_uchar
			ushort:(unsigned short)_ushort
			  uint:(unsigned int)_uint
			 ulong:(unsigned long)_ulong
			 float:(float)_float
			double:(double)_double
		   largeStruct:(MyLargeStruct)_lstr
		   smallStruct:(MySmallStruct)_sstr;

@end

@implementation MyClass
-(void)void_void {}
-(id)id_void { return 0; }

-(char)char_void { return 0; }
-(unsigned char)uchar_void { return 0; }
-(signed char)schar_void { return 0; }

-(short)short_void { return 0; }
-(unsigned short)ushort_void { return 0; }
-(signed short)sshort_void { return 0; }

-(int)int_void { return 0; }
-(unsigned int)uint_void { return 0; }
-(signed int)sint_void { return 0; }

-(long)long_void { return 0; }
-(unsigned long)ulong_void { return 0; }
-(signed long)slong_void { return 0; }

-(float)float_void { return 0; }
-(double)double_void { return 0; }

-(MyLargeStruct)largeStruct_void { MyLargeStruct str; return str; }
-(MySmallStruct)smallStruct_void { MySmallStruct str; return str; }



-(void)void_id:(id)_id {}

-(void)void_char:(char)_char {}
-(void)void_uchar:(unsigned char)_char {}
-(void)void_schar:(signed char)_char {}

-(void)void_short:(short)_short {}
-(void)void_ushort:(unsigned short)_short {}
-(void)void_sshort:(signed short)_short {}

-(void)void_int:(int)_int {}
-(void)void_uint:(unsigned int)_int {}
-(void)void_sint:(signed int)_int {}

-(void)void_long:(long)_long {}
-(void)void_ulong:(unsigned long)_long {}
-(void)void_slong:(signed long)_long {}

-(void)void_float:(float)_float {}
-(void)void_double:(double)_double {}

-(void)void_largeStruct:(MyLargeStruct)_str {}
-(void)void_smallStruct:(MySmallStruct)_str {}


-(MyLargeStruct)largeStruct_id:(id)_id
			  char:(char)_char
			 short:(short)_short
			   int:(int)_int
			  long:(long)_long
			 float:(float)_float
			double:(double)_double
		   largeStruct:(MyLargeStruct)_lstr
		   smallStruct:(MySmallStruct)_sstr { return _lstr; }

-(MySmallStruct)largeStruct_id:(id)_id
			 uchar:(unsigned char)_uchar
			ushort:(unsigned short)_ushort
			  uint:(unsigned int)_uint
			 ulong:(unsigned long)_ulong
			 float:(float)_float
			double:(double)_double
		   largeStruct:(MyLargeStruct)_lstr
		   smallStruct:(MySmallStruct)_sstr { return _sstr; }

@end

/*------------------------------------*/

int failed = 0;

void
test_mframe_build_signature(void)
{
  const char *mf_types;
  void *it = 0;
  GSMethod meth;
  GSMethodList list;
  Class cls = [MyClass class];
  NSMethodSignature *sig;
  unsigned int i;

  for (it = 0, list = class_nextMethodList(cls, &it);
       list != 0;
       list = class_nextMethodList(cls, &it))
    {
      id pool = [NSAutoreleasePool new];

      for (i = 0; i < list->method_count; i++)
	{
	  meth = &list->method_list[i];
	  sig = [NSMethodSignature signatureWithObjCTypes: meth->method_types];
	  mf_types = [sig methodType];
	  if (strcmp(meth->method_types, mf_types))
	    {
	      NSLog(@"sel: %s\nrts:%s\nmfs:%s",
		    GSNameFromSelector(meth->method_name),
		    meth->method_types, mf_types);
	      failed = 1;
	    }
	}

      [pool release];
    }
  
}


int
main(int argc, char *argv[])
{
  NSAutoreleasePool *pool;
  //  [NSAutoreleasePool enableDoubleReleaseCheck:YES];
  pool = [[NSAutoreleasePool alloc] init];

  NS_DURING
    {
      test_mframe_build_signature();
      if (failed)
	[NSException raise: NSInternalInconsistencyException
		     format: @"discrepancies between gcc/mframe signatures"];

      NSLog(@"MethodSignature Test Succeeded.");
    }
  NS_HANDLER
    {
      NSLog(@"MethodSignature Test Failed:");
      NSLog(@"%@ %@ %@",
	    [localException name],
	    [localException reason],
	    [localException userInfo]);
    }
  NS_ENDHANDLER

  [pool release];

  exit(0);
}


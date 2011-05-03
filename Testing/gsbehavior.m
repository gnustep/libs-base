/** gsbehavior - Program to test GSObjCAddClassBehavior.
   Copyright (C) 2003 Free Software Foundation, Inc.

   Written by:  David Ayers  <d.ayers@inode.at>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
*/


#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDebug.h>

#include <GNUstepBase/GSObjCRuntime.h>

/*------------------------------------*/
@interface MyClass : NSObject
-(const char *)text;
-(const char *)textBase;
@end
@implementation MyClass
-(void)myClassMain {};
-(const char *)text
{
  return "class_main";
}
-(const char *)textBase
{
  return "class_main_base";
}
@end

@interface  MyClass (Category1)
-(void)myClassCategory1;
@end
@implementation MyClass (Category1)
-(void)myClassCategory1 {};
-(const char *)text
{
  return "class_category_1";
}
@end

@interface  MyClass (Category2)
-(void)myClassCategory2;
@end
@implementation MyClass (Category2)
-(void)myClassCategory2 {};
-(const char *)text
{
  return "class_category_2";
}
@end

/*------------------------------------*/

@interface MyTemplate1 : NSObject
@end
@implementation MyTemplate1
@end

/*------------------------------------*/
/*------------------------------------*/

@interface MyTemplate2 : NSObject
-(const char *)text;
@end
@implementation MyTemplate2
-(const char *)text
{
  return "template_main";
}
@end

/*------------------------------------*/

@interface MyBehavior : NSObject
-(const char *)text;
-(const char *)textBase;
@end
@implementation MyBehavior
-(void)myBehaviorMain {};
-(const char *)text
{
  return "behavior_main";
}
-(const char *)textBase
{
  return "behavior_main_base";
}
@end
@interface  MyBehavior (Category1)
-(void)myBehaviorCategory1;
@end
@implementation MyBehavior (Category1)
-(void)myBehaviorCategory1 {};
-(const char *)text
{
  return "behavior_category_1";
}
@end

@interface  MyBehavior (Category2)
-(void)myBehaviorCategory2;
@end
@implementation MyBehavior (Category2)
-(void)myBehaviorCategory2 {};
-(const char *)text
{
  return "behavior_category_2";
}
@end

/*------------------------------------*/

void
test_basic(void)
{
  id myClass;
  id myBehavior;

  myClass = [MyClass new];
  myBehavior = [MyBehavior new];

  NSCAssert(strncmp([myClass text], "class_category", 14) == 0,
	    @"Default implementation isn't Category!");
  NSCAssert(strncmp([myBehavior text], "behavior_category", 17) == 0,
	    @"Default implementation isn't Category!");

  RELEASE(myClass);
  RELEASE(myBehavior);
}

void
test_create_list(void)
{
  GSMethodList myList;
  GSMethod myMethod;
  Class myClass;
  void *it;
  IMP imp_main;
  IMP imp_1;
  IMP imp_2;
  const char *types;
  id myObj;

  it = 0;
  myClass = [MyClass class];
  myObj = [myClass new];
  myList = GSMethodListForSelector(myClass, @selector(text), &it, YES);
  NSCAssert(myList,@"List is NULL!");
  myMethod = GSMethodFromList(myList, @selector(text), NO);
  NSCAssert(myMethod,@"Method is NULL!");
  imp_1 = myMethod->method_imp;

  myList = GSMethodListForSelector(myClass, @selector(text), &it, YES);
  NSCAssert(myList,@"List is NULL!");
  myMethod = GSMethodFromList(myList, @selector(text), NO);
  NSCAssert(myMethod,@"Method is NULL!");
  imp_2 = myMethod->method_imp;

  myList = GSMethodListForSelector(myClass, @selector(text), &it, YES);
  NSCAssert(myList,@"List is NULL!");
  myMethod = GSMethodFromList(myList, @selector(text), NO);
  NSCAssert(myMethod,@"Method is NULL!");
  imp_main = myMethod->method_imp;

  types = myMethod->method_types;

  myList = GSAllocMethodList(3);
  GSAppendMethodToList(myList, @selector(text_main), types, imp_main, YES);
  GSAppendMethodToList(myList, @selector(text_1), types, imp_1, YES);
  GSAppendMethodToList(myList, @selector(text_2), types, imp_2, YES);

  GSAddMethodList(myClass, myList, YES);
  GSFlushMethodCacheForClass(myClass);
  NSCAssert([myObj respondsToSelector:@selector(text_main)] == YES,
	    @"Add failed.");
  NSCAssert([myObj respondsToSelector:@selector(text_1)] == YES,
	    @"Add failed.");
  NSCAssert([myObj respondsToSelector:@selector(text_2)] == YES,
	    @"Add failed.");
  NSCAssert(strcmp([myObj text_main], "class_main") == 0,
	    @"Add failed to add correct implementation!");
  NSCAssert(strncmp([myObj text_1], "class_category", 14) == 0,
	    @"Add failed to add correct implementation!");
  NSCAssert(strncmp([myObj text_2], "class_category", 14) == 0,
	    @"Add failed to add correct implementation!");

}

void
test_reorder_list(void)
{
  Class myClass;
  id    myObj;
  GSMethodList list;

  myClass = [MyClass class];
  myObj = [MyClass new];

  list = GSMethodListForSelector(myClass, @selector(myClassMain), 0, YES);

  /* Remove */
  GSRemoveMethodList(myClass, list, YES);
  GSFlushMethodCacheForClass(myClass);
  NSCAssert([myObj respondsToSelector:@selector(myClassMain)] == NO,
	    @"Remove failed.");

  /* Add */
  GSAddMethodList(myClass, list, YES);
  GSFlushMethodCacheForClass(myClass);

  NSCAssert([myObj respondsToSelector:@selector(myClassMain)] == YES,
	    @"Add failed.");
  NSCAssert(strcmp([myObj text], "class_main") == 0,
	    @"Add failed to add correct implementation!");

  RELEASE(myClass);
}

void
test_exchange_method(void)
{
  Class myClass;
  Class myBehavior;
  id myClsObj;
  id myBhvObj;
  GSMethodList myListC;
  GSMethodList myListB;
  GSMethod myMethodC;
  GSMethod myMethodB;
  struct objc_method myMethodStructC;
  struct objc_method myMethodStructB;

  myClass = [MyClass class];
  myBehavior = [MyBehavior class];

  myClsObj = [myClass new];
  myBhvObj = [myBehavior new];

  NSCAssert(strcmp([myClsObj textBase], "class_main_base") == 0,
	    @"Wrong precondition!");
  NSCAssert(strcmp([myBhvObj textBase], "behavior_main_base") == 0,
	    @"Wrong precondition!");

  myListC = GSMethodListForSelector(myClass, @selector(textBase), 0, YES);
  myListB = GSMethodListForSelector(myBehavior, @selector(textBase), 0, YES);

  myMethodC = GSMethodFromList(myListC, @selector(textBase), NO);
  myMethodStructC = *myMethodC;
  myMethodC = &myMethodStructC;
  myMethodB = GSMethodFromList(myListB, @selector(textBase), NO);
  myMethodStructB = *myMethodB;
  myMethodB = &myMethodStructB;

  GSRemoveMethodFromList(myListC, @selector(textBase), NO);
  GSRemoveMethodFromList(myListB, @selector(textBase), NO);

  GSAppendMethodToList(myListC,
		       myMethodB->method_name,
		       myMethodB->method_types,
		       myMethodB->method_imp,
		       NO);
  GSAppendMethodToList(myListB,
		       myMethodC->method_name,
		       myMethodC->method_types,
		       myMethodC->method_imp,
		       NO);

  GSFlushMethodCacheForClass(myClass);
  GSFlushMethodCacheForClass(myBehavior);

  NSCAssert(strcmp([myClsObj textBase], "behavior_main_base") == 0,
	    @"Couldn't replace implementation!");
  NSCAssert(strcmp([myBhvObj textBase], "class_main_base") == 0,
	    @"Couldn't replace implementation!");

}

void
test_behavior1(void)
{
  Class myTmplClass;
  id myTmplObj;

  myTmplClass = [MyTemplate1 class];
  myTmplObj = [MyTemplate1 new];

  NSCAssert([myTmplObj respondsToSelector:@selector(text)] == NO,
	    @"Initial state invalid");
  GSObjCAddClassBehavior(myTmplClass, [MyClass class]);
  NSCAssert([myTmplObj respondsToSelector:@selector(text)] == YES,
	    @"Behavior failed");

}


void
test_behavior2(void)
{
  Class myTmplClass;
  id myTmplObj;

  myTmplClass = [MyTemplate2 class];
  myTmplObj = [MyTemplate2 new];

  NSCAssert([myTmplObj respondsToSelector:@selector(myClassCategory1)] == NO,
	    @"Initial state invalid");
  GSObjCAddClassBehavior(myTmplClass, [MyClass class]);
  NSCAssert([myTmplObj respondsToSelector:@selector(myClassCategory1)] == YES,
	    @"Behavior failed");

  NSCAssert(strcmp([myTmplObj text], "template_main") == 0,
	    @"Overwritten existing implementation!");
}

void
test_methodnames(void)
{
  id obj = [NSNotificationCenter defaultCenter];
  NSArray *names;

  names = GSObjCMethodNames(obj);
  NSDebugLog(@"obj:%@", names);
  names = GSObjCMethodNames([obj class]);
  NSDebugLog(@"class:%@", names);
}

int
main(int argc, char *argv[])
{
  NSAutoreleasePool *pool;
  //  [NSAutoreleasePool enableDoubleReleaseCheck:YES];
  pool = [[NSAutoreleasePool alloc] init];

  NS_DURING
    {
      test_methodnames();
      test_basic();
      test_create_list();
      test_reorder_list();
      test_exchange_method();

      NSLog(@"Behavior Test Succeeded.");
    }
  NS_HANDLER
    {
      NSLog(@"Behavior Test Failed:");
      NSLog(@"%@ %@ %@",
	    [localException name],
	    [localException reason],
	    [localException userInfo]);
      [localException raise];
    }
  NS_ENDHANDLER

  [pool release];

  exit(0);
}


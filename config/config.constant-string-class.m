/* Test that the compiler supports the -fconstant-string-class option
   Copyright (C) 2001 Free Software Foundation, Inc.

   Written by: Nicola Pero <nicola@brainstorm.co.uk>
   Created: June 2001
   
   This file is part of the GNUstep Base Library.
   
   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.
*/
#ifdef NeXT_RUNTIME
/* ignore this test with the NeXT runtime - never use
   -fconstant-string-class */
int main (int argc, char **argv)
{
  abort ();
  return 1;
}
#else /* GNU RUNTIME - the real test */

/* must be compiled compile using -fconstant-string-class=NSConstantString
   as an option to gcc.  If it doesn't work, it means your gcc doesn't
   support this option. */

#include <objc/objc.h>
#include <objc/Object.h>

/* Define our custom constant string class */
@interface NSConstantString : Object
{
   char *c_string;
   unsigned int len;
}
- (char *) customString;
@end
  
@implementation NSConstantString
- (char *) customString
{
    return c_string;
}
@end
  

int main (int argc, char **argv)
{
   /* Create a test constant string */
   NSConstantString *string = @"Antonio Valente";
   
   /* Check that it really works */
   if (strcmp ([string customString], "Antonio Valente"))
     {
       abort ();
     }
   
   return 0;
}
#endif /* GNU RUNTIME */

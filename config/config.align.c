/* This program will most likely crash on systems that need shorts and ints
   to be word aligned
  Copyright (C) 2005 Free Software Foundation

  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

*/

int main ()
{
 char buf[12];
 char *ptr = buf;
 short sval = 4;
 int   ival = 3;
 if (0 == ((int)ptr % 2))
   {
     ptr++;
   }
 *(short *)ptr = sval;
 *(int *)ptr = ival;
 ptr[0] = 0;
 puts (ptr);   /* force compiler not to optimise out the above assignments */
 exit (0);
}


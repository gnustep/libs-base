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
  short sval = 4;
  int   ival = 3;
  *(short *)(buf+1) = sval;
  *(int *)(buf+1) = ival;
  buf[0] = 0;
  puts (buf);	/* force compiler not to optimise out the above assignments */
  exit (0);
}

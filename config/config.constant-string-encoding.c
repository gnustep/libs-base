/* 
  Copyright (C) 2011 Free Software Foundation

  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

*/

int main ()
{
  /* Check that latin1 pound sign in source is utf8 in executable
   */
  const unsigned char *str = "£";
  if (str[0] != 0xc2 || str[1] != 0xa3)
    {
      return 1;
    }
  return 0;
}

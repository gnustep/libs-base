/*
 * Check to see if the final cmdline arg recorded in the /proc filesystem
 * is terminated by a nul.
 */
#include <stdio.h>
int main()
{
  char	buf[32];
  FILE	*fptr;
  int	result = 1;
  int	c;

  sprintf(buf, "/proc/%d/cmdline", getpid());
  fptr = fopen(buf, "r");
  if (fptr != 0)
    {
      while ((c = fgetc(fptr)) != EOF)
	{
	  result = c;
	}
      fclose(fptr);
    }
  if (result != 0)
    {
      result = 1;
    }
  return result;
}

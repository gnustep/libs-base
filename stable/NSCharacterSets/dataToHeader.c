/*
 * A trivial C program to read characterset data files and produce a C
 * header file to be included into NSCharacterSet.m
 * Pass it the names of the data files as arguments.
 */
#include	<stdio.h>
#include	<string.h>

int
main(int argc, char **argv)
{
  int	i;
  int	c;
  FILE	*o;

  if (argc < 2)
    {
      fprintf(stderr, "Expecting names of data files to convert\n");
      return 1;
    }
  o = fopen("NSCharacterSetData.h", "w");
  for (i = 1; i < argc; i++)
    {
      FILE	*f;
      char	name[BUFSIZ];
      int	j;
      int	sep = '{';

      strcpy(name, argv[i]);
      j = strlen(name) - 4;
      if (j < 0 || strcmp(&name[j], ".dat") != 0)
	{
	  fprintf(stderr, "Bad file name '%s'\n", name);
	  return 1;
	}
      f = fopen(name, "r");
      if (f == NULL)
	{
	  fprintf(stderr, "Unable to read '%s'\n", name);
	  return 1;
	}
      name[j] = '\0';
      fprintf(o, "static unsigned char %s[8192] = ", name);
      while ((c = fgetc(f)) != EOF)
	{
	  fprintf(o, "%c\n'\\x%02x'", sep, c);
	  sep = ',';
	}
      fprintf(o,"};\n");
      fclose(f);
    }
  fclose(o);
  return 0;
}


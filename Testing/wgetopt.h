#if (defined __MINGW__)
/* A simple implementation of getopt() */
static int
indexof(char c, char *string)
{
  int i;

  for (i = 0; i < strlen(string); i++)
    {
      if (string[i] == c)
	{
	  return i;
	}
    }
  return -1;
}

static char *optarg;
static int optind;
static char
getopt(int argc, char **argv, char *options)
{
  static char	*arg;
  int		index;
  char		retval = '\0';

  optarg = NULL;
  if (optind == 0)
    {
      optind = 1;
    }
  while (optind < argc)
    {
      arg = argv[optind];
      if (strlen(arg) == 2)
	{
	  if (arg[0] == '-')
	    {
	      if ((index = indexof(arg[1], options)) != -1)
		{
		  retval = arg[1];
		  if (index < strlen(options))
		    {
		      if (options[index+1] == ':')
			{
			  if (optind < argc-1)
			    {
			      optind++;
			      optarg = argv[optind];
			    }
			  else
			    {
			      return -1; /* ':' given, but argv exhausted */
			    }
			}
		    }
		}
	    }
	}
      optind++;
      return retval;
    }
  return -1;
}
#endif

/* Exit with status 0 if vasprintf returns the length of the string printed.
   Some systems return a pointer to the string instead. */ 

int main ()
{
  char *buf;
  if (vasprintf (&buf, "1234") == 4)
    exit (0);
  exit (-1);
}

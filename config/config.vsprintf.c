/* Exit with status 0 if vsprintf returns the length of the string printed.
   Some systems return a pointer to the string instead. */ 

int main ()
{
  char buf[128];
  if (vsprintf (buf, "1234") == 4)
    exit (0);
  exit (-1);
}

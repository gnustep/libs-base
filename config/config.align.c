/* This program will most likely crash on systems that need shorts and ints
   to be word aligned
*/

int main ()
{
  char buf[12];
  short sval = 4;
  int   ival = 3;
  *(short *)(buf+1) = sval;
  *(int *)(buf+1) = ival;
  exit (0);
}

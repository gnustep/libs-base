#include <Foundation/NSCharacterSet.h>

int main()
{
  NSCharacterSet *alpha = [NSCharacterSet alphanumericCharacterSet];

  if (alpha)
    printf("obtained alphanumeric character set\n");
  else
    printf("unable to obtain alphanumeric character set\n");

  exit(0);
}

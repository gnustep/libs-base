#include <objects/StdioStream.h>

int main()
{  
  char b[100];
  int len;
  id s = [[StdioStream alloc] initWithPipeFrom: @"cat /etc/group | sort"];

  while ((len = [s readBytes:b length:99]) > 0)
    {
      b[len] = '\0';
      printf("[%d]: %s\n", len, b);
    }

  exit(0);
}

#include <objc/objc-api.h>

int main (void)
{
  IMP (*__objc_msg_forward1)(SEL) = __objc_msg_forward;
  return 0;
}

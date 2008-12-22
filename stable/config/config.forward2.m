#include <objc/objc-api.h>

int main (void)
{
  IMP (*__objc_msg_forward1)(id,SEL) = __objc_msg_forward2;
  return 0;
}

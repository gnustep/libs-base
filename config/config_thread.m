/* Test whether Objective-C runtime was compiled with thread support */

/* From thr.c */
extern int __objc_init_thread_system(void);

int
main()
{
  return (__objc_init_thread_system());
}


#ifdef STRICT_MACOS_X
#	define OBJC_NONPORTABLE __attribute__((error("Function not supported by the Apple runtime")))
#else
#	define OBJC_NONPORTABLE
#endif

#if !defined(__DEPRECATE_DIRECT_ACCESS) || defined(__OBJC_LEGACY_GNU_MODE__) || defined(__OBJC_RUNTIME_INTERNAL__)
#	define OBJC_DEPRECATED
#else
#	define OBJC_DEPRECATED __attribute__((deprecated))
#endif

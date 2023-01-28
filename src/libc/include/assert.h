#pragma once

#ifdef NDEBUG
#define assert(condition) ((void)0)
#else
extern void _assert_failure(const char*, unsigned int);
#define assert(condition) ((condition) ? (void)0 : _assert_failure(__FILE__, __LINE__))
#endif


#include <stddef.h>
#include <stdint.h>
#include <string.h>

char* strchr(const char* s, int c) {
    while (*s != '\0' && *s != c)
        ++s;

    return c == *s ? (char*)s : NULL;
}

size_t strlen(const char* s) {
    const char* p = s;
    while (*p != '\0')
        ++p;
    return p - s;
}

char* strcpy(char* dest, const char* src) {
    char* const dest_start = dest;
    while (*src != '\0')
        *dest++ = *src++;
    *dest = '\0';
    return dest_start;
}

char* strcat(char* dest, const char* src) {
    return strcpy(dest + strlen(dest), src);
}

int strcmp(const char* s1, const char* s2) {
    while (*s1 != '\0' && *s1 == *s2) {
        ++s1;
        ++s2;
    }
    return (*s1 > *s2) - (*s1 < *s2);
}

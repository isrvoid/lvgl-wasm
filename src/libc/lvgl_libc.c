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

void* memcpy(void* dest_, const void* src_, size_t n) {
    uint8_t* dest = dest_;
    const uint8_t* src = src_;
    const uint8_t* const src_end = src + n;
    while (src < src_end)
        *dest++ = *src++;
    return dest_;
}

int memcmp(const void* p1_, const void* p2_, size_t n) {
    const uint8_t* p1 = p1_;
    const uint8_t* p2 = p2_;
    size_t i = 0;
    while (i < n && p1[i] == p2[i])
        ++i;
    return (p1[i] > p2[i]) - (p1[i] < p2[i]);
}

void* memset(void* p_, int v, size_t n) {
    uint8_t* p = p_;
    const uint8_t* const end = p + n;
    while (p < end)
        *p++ = (uint8_t)v;
    return p_;
}

void* memmove(void* dest_, const void* src_, size_t n) {
    const uint8_t* const src_start = src_;
    if (dest_ <= src_ || dest_ >= src_start + n)
        return memcpy(dest_, src_, n);
    else {
        const uint8_t* src = src_start + n;
        uint8_t* dest = (uint8_t*)dest_ + n;
        while (--src >= src_start)
            *--dest = *src;
        return dest_;
    }
}

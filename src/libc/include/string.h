#pragma once

#include <stddef.h>

char* strchr(const char*, int);
size_t strlen(const char*);
char* strcpy(char*, const char*);
char* strcat(char*, const char*);
int strcmp(const char*, const char*);
void* memcpy(void*, const void*, size_t);
int memcmp(const void*, const void*, size_t);
void* memset(void*, int, size_t);
void* memmove(void*, const void*, size_t);

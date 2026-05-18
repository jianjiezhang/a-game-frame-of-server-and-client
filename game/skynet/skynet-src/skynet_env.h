#ifndef SKYNET_ENV_H
#define SKYNET_ENV_H
#include <stdbool.h>
const char * skynet_getenv(const char *key);
void skynet_setenv(const char *key, const char *value);
const char * skynet_getvenv(const char *key);
bool skynet_setvenv(const char *key, const char *value);

void skynet_env_init();

#endif

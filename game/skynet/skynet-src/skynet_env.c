#include "skynet.h"
#include "skynet_env.h"
#include "spinlock.h"

#include <lua.h>
#include <lauxlib.h>

#include <stdlib.h>
#include <assert.h>

struct skynet_env {
	struct spinlock lock;
	lua_State *L;
};
struct skynet_varenv{
	struct spinlock lock;
	lua_State *L;
};

static struct skynet_env *E = NULL;
static struct skynet_varenv *VE = NULL;

const char * 
skynet_getenv(const char *key) {
	SPIN_LOCK(E)

	lua_State *L = E->L;
	
	lua_getglobal(L, key);
	const char * result = lua_tostring(L, -1);
	lua_pop(L, 1);

	SPIN_UNLOCK(E)

	return result;
}
const char *
skynet_getvenv(const char *key){
	SPIN_LOCK(E)

	lua_State *L = VE->L;
	lua_getglobal(L, key);
	const char *result = lua_tostring(L, -1);
	lua_pop(L, 1);

	SPIN_UNLOCK(E)
	return result;
}


void 
skynet_setenv(const char *key, const char *value) {
	SPIN_LOCK(E)
	
	lua_State *L = E->L;
	lua_getglobal(L, key);
	assert(lua_isnil(L, -1));
	lua_pop(L,1);
	lua_pushstring(L,value);
	lua_setglobal(L,key);

	SPIN_UNLOCK(E)
}
bool 
skynet_setvenv(const char *key, const char *value){
	SPIN_LOCK(E)

	lua_State *L = VE->L;
	lua_pushstring(L, value);
	lua_setglobal(L, key);

	SPIN_UNLOCK(E)
	return true;
}


void
skynet_env_init() {
	E = skynet_malloc(sizeof(*E));
	VE = skynet_malloc(sizeof(*VE));
	SPIN_INIT(E)
	SPIN_INIT(VE)
	E->L = luaL_newstate();
	VE->L = luaL_newstate();
}

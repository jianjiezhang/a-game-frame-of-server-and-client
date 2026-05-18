

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "mysql/mysql.h"
#include <string.h>

typedef struct{
    MYSQL *conn;
}db_conn;

static int l_connect(lua_State *L){
    const char *host = luaL_checkstring(L, 1);
    const char *user = luaL_checkstring(L, 2);
    const char *passwd = luaL_checkstring(L, 3);
    const char *db = luaL_checkstring(L, 4);
    int port = luaL_checkinteger(L, 5);

    db_conn *dbc = (db_conn*)lua_newuserdata(L, sizeof(db_conn));
    dbc->conn = mysql_init(NULL);

    if(!mysql_real_connect(dbc->conn, host, user, passwd, db, port, NULL, 0)){
        return luaL_error(L, mysql_error(dbc->conn));
    }

    luaL_getmetatable(L, "DB_CONN");
    lua_setmetatable(L, -2);

    return 1;
}

static int l_query(lua_State *L){
    db_conn *dbc = luaL_checkudata(L, 1, "DB_CONN");
    const char *sql = luaL_checkstring(L, 2);

    if(mysql_query(dbc->conn, sql)){
        return luaL_error(L, mysql_error(dbc->conn));
    }

    MYSQL_RES *res = mysql_store_result(dbc->conn);

    if(!res) {
        lua_pushboolean(L, 1);
        return 1;
    }

    int num_fields = mysql_num_fields(res);
    MYSQL_FIELD *fields = mysql_fetch_fields(res);
    
    lua_newtable(L);

    MYSQL_ROW row;
    int row_idx = 1;

    while((row = mysql_fetch_row(res))){
        unsigned long *lengths = mysql_fetch_lengths(res);
        lua_pushinteger(L, row_idx++);
        lua_newtable(L);
        
        for(int i = 0;i< num_fields; i++){
            lua_pushstring(L, fields[i].name);
            if(row[i]){
                lua_pushlstring(L, row[i], lengths[i]);
            }
            else{
                lua_pushnil(L);
            }
            lua_settable(L, -3);
        }
        lua_settable(L, -3);
    }

    mysql_free_result(res);
    return 1;
}

static int l_close(lua_State *L){
    db_conn *dbc = luaL_checkudata(L, 1, "DB_CONN");
    if(dbc->conn){
        mysql_close(dbc->conn);
        dbc->conn = NULL;
    }
    return 0;
}

static int l_begin(lua_State *L){
    db_conn *dbc = luaL_checkudata(L, 1, "DB_CONN");
    if(mysql_query(dbc->conn, "START_TRANSACTION")){
        return luaL_error(L, mysql_error(dbc->conn));
    }
    return 0;
}

static int l_commit(lua_State *L){
    db_conn *dbc = luaL_checkudata(L, 1, "DB_CONN");
    if(mysql_query(dbc->conn, "COMMIT")){
        return luaL_error(L, mysql_error(dbc->conn));
    }
    return 0;
}

static int l_rollback(lua_State *L){
    db_conn *dbc = luaL_checkudata(L, 1, "DB_CONN");
    if(mysql_query(dbc->conn, "ROLLBACK")){
        return luaL_error(L, mysql_error(dbc->conn));
    }
    return 0;
}

static const luaL_Reg dblib[] = {
    {"connect", l_connect},
    {"query", l_query},
    {"close", l_close},
    {"begin", l_begin},
    {"commit", l_commit},
    {"rollback", l_rollback},
    {NULL, NULL}
};

int luaopen_db_mysql(lua_State *L){
    luaL_newmetatable(L, "DB_CONN");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_setfuncs(L, dblib, 0);

    return 1;
}




















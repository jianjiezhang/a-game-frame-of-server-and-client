
#include<iostream>
#include<sys/socket.h>
#include<arpa/inet.h>
#include<unistd.h>
#include<string.h>
#include<cstdlib>
#include <readline/readline.h>
#include<readline/history.h>
#include<stdio.h>

extern "C"{
    #include "lua.h"
    #include "lauxlib.h"
    #include "lualib.h"
}

static int l_connect(lua_State *L)
{
    const char *ip = luaL_checkstring(L, 1);
    int port = luaL_checkinteger(L, 2);
    int sock = socket(AF_INET, SOCK_STREAM, 0);

    sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    inet_pton(AF_INET, ip, &addr.sin_addr);

    if(connect(sock, (sockaddr*)&addr, sizeof(addr)) != 0){
        lua_pushnil(L);
        return 1;
    }

    lua_pushinteger(L, sock);
    return 1;
}
static int l_send(lua_State *L)
{
    int sock = luaL_checkinteger(L, 1);
    size_t len;
    const char* data = luaL_checklstring(L, 2, &len);
    if(len > 0xffff){
        return luaL_error(L, "data too large");
    }
    uint16_t nlen = htons((uint16_t)len);

    size_t total = 2 + len;
    char*buf = (char*)malloc(total);
    if(!buf){
        return luaL_error(L, "malloc failed");
    }
    memcpy(buf, &nlen, 2);
    memcpy(buf + 2, data, len);
    ssize_t ret = send(sock, buf, total, 0);
    
    free(buf);

    if(ret < 0)
        return luaL_error(L, "send failed");
    return 0;
}
static int recv_all(int sock, void* buf, size_t len)
{
    size_t received = 0;
    while(received < len)
    {
        ssize_t n = recv(sock, (char*)buf + received, len - received, 0);
        if(n == 0)
            return 0;
        if(n < 0)
            return -1;
        received += n;
    }
    return 1;
}
static int l_recv(lua_State *L)
{
    int sock = luaL_checkinteger(L, 1);

    uint16_t nlen;
    int r = recv_all(sock, &nlen, 2);
    if(r <= 0){
        lua_pushnil(L);
        return 1;
    }

    uint16_t len = ntohs(nlen);
    if(len == 0 || len > 65535){
        lua_pushnil(L);
        return 1;
    }
    char* buffer = (char*)malloc(len);
    if(!buffer){
        lua_pushnil(L);
        return 1;
    }

    r = recv_all(sock, buffer, len);
    if(r <= 0)
    {
        free(buffer);
        lua_pushnil(L);
        return 1;
    }

    lua_pushlstring(L, buffer, len);
    free(buffer);

    return 1;
}

static int l_close(lua_State *L)
{
    int sock = luaL_checkinteger(L, 1);
    close(sock);
    return 0;
}

static int ludp_create(lua_State *L)
{
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if(sock < 0){
        lua_pushnil(L);
        return 1;
    }

    lua_pushinteger(L, sock);
    return 1;
}
static int ludp_send(lua_State *L)
{
    int sock = luaL_checkinteger(L, 1);
    const char* ip = luaL_checkstring(L, 2);
    int port = luaL_checkinteger(L, 3);

    size_t len;
    const char *data = luaL_checklstring(L, 4, &len);
    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    inet_pton(AF_INET, ip, &addr.sin_addr);

    sendto(sock, data, len, 0, (sockaddr*)&addr, sizeof(addr));
    return 0;
}
static int ludp_recv(lua_State *L)
{
    int sock = luaL_checkinteger(L, 1);
    
    char buffer[65536];
    sockaddr_in from{};
    socklen_t fromlen = sizeof(from);
    int len = recvfrom(sock, buffer, sizeof(buffer), 0, (sockaddr*)&from, &fromlen);

    if(len <= 0)
    {
        lua_pushnil(L);
        return 1;
    }

    char ip[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &from.sin_addr, ip, sizeof(ip));
    int port = ntohs(from.sin_port);

    lua_pushlstring(L, buffer, len);
    lua_pushstring(L, ip);
    lua_pushinteger(L, port);

    return 3;
}

static int ludp_close(lua_State*L)
{
    int sock = luaL_checkinteger(L, 1);
    close(sock);
    return 0;
}

static int ludp_bind(lua_State *L)
{
    int sock = luaL_checkinteger(L, 1);
    const char *ip = luaL_checkstring(L, 2);
    int port = luaL_checkinteger(L, 3);

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    inet_pton(AF_INET, ip, &addr.sin_addr);

    int ret = bind(sock, (sockaddr*)&addr, sizeof(addr));
    if(ret != 0){
        lua_pushboolean(L, 0);
        return 1;
    }

    lua_pushboolean(L, 1);
    return 1;
}

static int write_stdin(lua_State *L)
{
    return 0;
}
static int read_stdin(lua_State *L)
{
    char *line = readline("> ");
    add_history(line);
    lua_pushstring(L, line);
    free(line);
    return 1;
}

static const luaL_Reg funcs[]={
    {"connect", l_connect},
    {"send", l_send},
    {"recv", l_recv},
    {"close", l_close},
    {"write_stdin", write_stdin},
    {"read_stdin", read_stdin},

    {"udp_create", ludp_create},
    {"udp_send", ludp_send},
    {"udp_recv", ludp_recv},
    {"udp_close", ludp_close},
    {"udp_bind", ludp_bind},
    {NULL, NULL}
};

extern "C" int luaopen_client_socket(lua_State *L){
    luaL_newlib(L, funcs);
    return 1;
}


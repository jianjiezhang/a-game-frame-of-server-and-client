


#include<iostream>
#include<thread>
#include<vector>
#include<string>
#include<chrono>

extern "C"{
    #include "lua.h"
    #include "lauxlib.h"
    #include "lualib.h"
}

void run_client(int id)
{
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    //luaL_requiref(L, "client_socket", luaopen_client_socket， 1);
    //lua_pop(L, 1);

    if(luaL_loadfile(L, "client.lua")){
        std::cerr<<"Load client.lua failed:"<<lua_tostring(L, -1)<<std::endl;
        lua_close(L);
        return;
    }

    lua_pushinteger(L, id);
    if(lua_pcall(L, 1, 0, 0)!= LUA_OK){
        std::cerr<<"Lua runtime error: "<<lua_tostring(L, -1)<<std::endl;
    }
    lua_close(L);
}
int main(int argc, char *argv[])
{
    int client_count = 1;
    if(argc > 1){
        client_count = std::stoi(argv[1]);
    }
    std::cout<<"Start "<<client_count<<" clients"<<std::endl;

    std::vector<std::thread> threads;

    for(int i = 0;i<client_count;i++)
    {
        threads.emplace_back(run_client, i + 1);
    }
    for(auto &t : threads){
        t.join();
    }
    std::cout<< "ALL clients finished."<<std::endl;
    return 0;
}







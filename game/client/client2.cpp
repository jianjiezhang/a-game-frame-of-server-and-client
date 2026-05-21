

#include <iostream>
#include<thread>
#include <vector>
#include<queue>
#include<mutex>
#include<condition_variable>
#include<atomic>
#include<unordered_map>
#include<cstring>
#include<cerrno>
#include<unistd.h>
#include<arpa/inet.h>

#include<sys/socket.h>
#include<sys/epoll.h>
#include<sys/un.h>
#include "spinlock.h"
#include <chrono>

extern "C"{
    #include "lua.h"
    #include "lauxlib.h"
    #include "lualib.h"
}

#define SERVER_IP "127.0.0.1"
#define SERVER_PORT 8894
#define CONTROL_PATH "./client_ctrl.sock"
#define CONTROL_IP "127.0.0.1"
#define CONTROL_PORT 8895
#define MAX_EVENTS 64

struct message{
    enum type{NET_MSG, INPUT_MSG, TIMER_MSG} type;
    std::string data;
};
struct client{
    int id;
    int sockfd;
    lua_State *L;

    std::queue<message> queue;
    std::queue<std::string> send_queue;
    std::mutex mtx;
    std::condition_variable cv;
};

std::atomic<bool> running(true);
std::vector<client*> clients;
std::unordered_map<int, int> fd_to_client;
int epfd;
int control_listen_fd;

int connect_server()
{
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(SERVER_PORT);
    inet_pton(AF_INET, SERVER_IP, &addr.sin_addr);

    if(connect(sock, (sockaddr*)&addr, sizeof(addr)) != 0){
        return -1;
    }
    return sock;
}
//修改
void send_packet(int sock, const std::string &data)
{
    uint16_t len = data.size();
    uint16_t nlen = htons((uint16_t)data.size());
    if (len > 0xffff){
        printf("send packet length too large");
        return;
    }
    size_t total = 2+len;
    char *buf = (char*)malloc(total);
    memcpy(buf, &nlen, 2);
    memcpy(buf+2, data.c_str(), len);
    ssize_t ret = send(sock, buf, len + 2, 0);
    free(buf);
    if (ret < 0)
        printf("send failed");
}

int recv_all(int sock, void*buf, size_t len)
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
std::string recv_packet(int sock)
{
    uint16_t nlen;
    int r = recv_all(sock, &nlen, 2);
    if(r <= 0) return "";

    uint16_t len = ntohs(nlen);
    if (len==0 || len>65535){
        printf("recv packet error:%d\n", len);
    }
    std::string buf(len, 0);
    r = recv_all(sock, buf.data(), len);
    if(r <= 0){
        printf("recv packet data error\n");
    }
    return buf;
}

static int l_send(lua_State*L)
{
    int id = luaL_checkinteger(L, 1);
    const char*msg = luaL_checkstring(L, 2);
    client*c = clients[id-1];
    {
        std::lock_guard<std::mutex> lock(c->mtx);
        c->send_queue.push(msg);
    }
    return 0;
}

void client_thread(client*c)
{
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    lua_register(L, "send_to_server", l_send);
    if(luaL_dofile(L, "client2.lua")!= LUA_OK)
    {
        std::cout<<lua_tostring(L, -1)<<std::endl;
        return;
    }
    lua_getglobal(L, "init");
    lua_pushinteger(L, c->id);

    if(lua_pcall(L, 1, 0, 0)!= LUA_OK)
    {
        std::cout<<lua_tostring(L, -1)<<std::endl;
    }

    c->L = L;
    while(running)
    {
        std::unique_lock<std::mutex> lock(c->mtx);
        c->cv.wait(lock, [&]{return !c->queue.empty() || !running;});

        while(!c->queue.empty())
        {
            message msg = c->queue.front();
            c->queue.pop();
            lock.unlock();

            if(msg.type == message::NET_MSG)
            {
                lua_getglobal(L, "on_message");
                lua_pushstring(L, msg.data.c_str());
                lua_pcall(L, 1, 0, 0);
            }
            else if(msg.type == message::TIMER_MSG)
            {
                lua_getglobal(L, "on_timer");
                if(lua_isfunction(L, -1))
                {
                    if(lua_pcall(L, 0, 0, 0) != LUA_OK)
                    {
                        std::cout<<lua_tostring(L, -1) << std::endl;
                        lua_pop(L, 1);
                    }
                }
                else{
                    lua_pop(L, 1);
                }
            }
            else
            {
                lua_getglobal(L, "on_input");
                lua_pushstring(L, msg.data.c_str());
                lua_pcall(L, 1, 0, 0);
            }
//不清楚
            lock.lock();
        }
    }
    lua_close(L);
}

void network_thread()
{
    epfd = epoll_create1(0);
    epoll_event events[MAX_EVENTS];

    control_listen_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    strcpy(addr.sun_path, CONTROL_PATH);
    unlink(CONTROL_PATH);
    bind(control_listen_fd, (sockaddr*)&addr, sizeof(addr));
    listen(control_listen_fd, 1024);
    epoll_event control_ev{};
    control_ev.events = EPOLLIN;
    control_ev.data.fd = control_listen_fd;
    epoll_ctl(epfd, EPOLL_CTL_ADD, control_listen_fd, &control_ev);

    for(auto c : clients)
    {
        epoll_event ev{};
        ev.events = EPOLLIN | EPOLLOUT;
        ev.data.fd = c->sockfd;
        epoll_ctl(epfd, EPOLL_CTL_ADD, c->sockfd, &ev);
        fd_to_client[c->sockfd] = c->id;
    }

    while(running)
    {
        int n = epoll_wait(epfd, events, MAX_EVENTS, 1000);
        for(int i = 0;i<n;i++)
        {
            int fd = events[i].data.fd;
            if(fd == control_listen_fd) //管理线程
            {
                int cfd = accept(control_listen_fd, NULL, NULL);
                epoll_event cev{};
                cev.events = EPOLLIN;
                cev.data.fd = cfd;
                epoll_ctl(epfd, EPOLL_CTL_ADD, cfd, &cev);
            }
            else if(fd_to_client.find(fd) == fd_to_client.end()) //标准输入线程
            {
                char buf[1024];
                int r = read(fd, buf, sizeof(buf)-1);
                if (r <= 0)
                {
                    close(fd);
                    epoll_ctl(epfd, EPOLL_CTL_DEL, fd, NULL);
                    continue;
                }
                buf[r] = 0;
                if(strncmp(buf, "STOP", 4) == 0)
                {
                    running = false;
                }
                else if(strncmp(buf, "INPUT", 5)== 0)
                {
                    int id;
                    char msg[512];
                    sscanf(buf, "INPUT %d %[^\n]", &id, msg);

                    if(id > 0 && id <= clients.size())
                    {
                        client*c = clients[id - 1];
                        std::lock_guard<std::mutex> lock(c->mtx);
                        c->queue.push({message::INPUT_MSG, msg});
                        c->cv.notify_one();
                    }
                }
            }
            else //网络消息线程
            {
                int cid = fd_to_client[fd];
                if (events[i].events & EPOLLOUT)
                {
                    client *c = clients[cid - 1];
                    std::lock_guard<std::mutex> lock(c->mtx);
                    while(!c->send_queue.empty())
                    {   
                        send_packet(c->sockfd, c->send_queue.front());
                        c->send_queue.pop();
                    }
                }
                if (events[i].events & EPOLLIN){
                    std::string msg = recv_packet(fd);
                    if(msg.empty()) continue;
                    
                    client *c = clients[cid -1];
                    {
                        std::lock_guard<std::mutex> lock(c->mtx);
                        c->queue.push({message::NET_MSG, msg});
                    }
                    c->cv.notify_one();
                }
            }
        }
    }
    close(epfd);
    close(control_listen_fd);
    unlink(CONTROL_PATH);
}

void control_thread()
{
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if(fd < 0)
    {
        std::cout << "[control] create tcp socket failed, errno=" << errno << "\n";
        return;
    }

    int opt = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(CONTROL_PORT);
    inet_pton(AF_INET, CONTROL_IP, &addr.sin_addr);

    if(bind(fd,(sockaddr*)&addr, sizeof(addr)) != 0)
    {
        std::cout << "[control] bind failed " << CONTROL_IP << ":" << CONTROL_PORT << ", errno=" << errno << "\n";
        close(fd);
        return;
    }
    if(listen(fd, 5) != 0)
    {
        std::cout << "[control] listen failed, errno=" << errno << "\n";
        close(fd);
        return;
    }
    std::cout << "[control] tcp listen on " << CONTROL_IP << ":" << CONTROL_PORT << "\n";

    while(running)
    {
        int cfd = accept(fd, NULL, NULL);
        if (cfd < 0) continue;
        std::cout << "[control] accepted attach connection\n";

        char buf[1024];
        int n = read(cfd, buf, sizeof(buf) - 1);
        if (n <= 0) {close(cfd); continue;}

        buf[n] = 0;

        if(strncmp(buf, "STOP", 4) == 0)
        {
            running = false;
        }
        else if(strncmp(buf, "INPUT", 5) == 0)
        {
            int id;
            char msg[512];
            sscanf(buf, "INPUT %d %[^\n]", &id, msg);

            if(id > 0 && id <= clients.size())
            {
                client* c = clients[id - 1];
                {
                    std::lock_guard<std::mutex> lock(c->mtx);
                    c->queue.push({message::INPUT_MSG, msg});
                }
                c->cv.notify_one();
            }
        }
        close(cfd); //修改
    }
    close(fd);
}

void timer_thread()
{
    while(running)
    {
        auto now = std::chrono::steady_clock::now();
        for(auto c : clients)
        {
            {
                std::lock_guard<std::mutex> lock(c->mtx);
                c->queue.push({message::TIMER_MSG, ""});
            }
            c->cv.notify_one();
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(2));
    }
}

void attach_mode(int id)
{
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(CONTROL_PORT);
    inet_pton(AF_INET, CONTROL_IP, &addr.sin_addr);

    std::cout << "[attach] connecting to " << CONTROL_IP << ":" << CONTROL_PORT << " ...\n";
    if(connect(fd, (sockaddr*)&addr, sizeof(addr))!= 0)
    {
        std::cout << "master not running, connect failed errno=" << errno << "\n";
        return;
    }
    std::cout << "[attach] connected\n";
    while(true)
    {
        std::string line;
        std::getline(std::cin, line);

        std::string cmd = "INPUT " + std::to_string(id) + " " + line;
        send(fd, cmd.c_str(), cmd.size(), 0);
    }
}

void stop_mode()
{
    int fd = socket(AF_INET, SOCK_STREAM, 0);

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(CONTROL_PORT);
    inet_pton(AF_INET, CONTROL_IP, &addr.sin_addr);

    if(connect(fd, (sockaddr*)&addr, sizeof(addr))!= 0){
        std::cout << "master not running, connect failed errno=" << errno << "\n";
        return;
    }

    std::string cmd = "STOP";
    send(fd, cmd.c_str(), cmd.size(), 0);
    close(fd);
}
void master_mode()
{
    int client_count = 2;

    for(int i = 0;i<client_count;i++)
    {
        client*c = new client();
        c->id = i+1;
        c->sockfd = connect_server();
        if(c->sockfd == -1){
            fprintf(stderr, "can not connect to the server...\n");
            return;
        }
        //c->L = luaL_newstate();
        clients.push_back(c);

        std::thread(client_thread, c).detach();
    }

    std::thread(network_thread).detach();
    std::thread(timer_thread).detach();
    std::thread(control_thread).detach();

    std::cout<<"master running ...\n";
    while(running)
        std::this_thread::sleep_for(std::chrono::seconds(1));
    std::cout<<"Exit\n";
}

int main(int argc, char *argv[])
{
    if(argc == 1)
        master_mode();
    else if(strcmp(argv[1], "stop") == 0)
        stop_mode();
    else
        attach_mode(atoi(argv[1]));
    return 0;
}

























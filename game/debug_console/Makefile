


socket:
	g++ -O2 -fPIC --shared client_socket.cpp \
	-o client_socket.so \
	-I/mnt/hgfs/share2/game/client/lua-5.5.0/src/ \
	-L/mnt/hgfs/share2/game/client/lua-5.5.0/src/ \
	 -lm -ldl -lpthread -llua -lreadline

client2:
	g++ -O2 client2.cpp -o client2 \
	-I/mnt/hgfs/share2/game/client/lua-5.5.0/src/ \
	-L/mnt/hgfs/share2/game/client/lua-5.5.0/src/ \
	-ldl -lpthread -llua -lm \
	-std=c++17

main:
	g++ -O2 client.cpp -o client \
	-I/mnt/hgfs/share2/game/client/lua-5.5.0/src/ \
	-L/mnt/hgfs/share2/game/client/lua-5.5.0/src/ \
	-ldl -lpthread -llua -lm

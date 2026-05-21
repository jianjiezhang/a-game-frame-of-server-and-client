


socket:
	g++ -O2 -fPIC --shared client_socket.cpp \
	-o client_socket.so \
	-I./lua-5.5.0/src/ \
	-L./lua-5.5.0/src/ \
	 -lm -ldl -lpthread -llua

client2:
	g++ -O2 client2.cpp -o client2 \
	-I./lua-5.5.0/src/ \
	-L./lua-5.5.0/src/ \
	-ldl -lpthread -llua -lm \
	-std=c++17

main:
	g++ -O2 client.cpp -o client \
	-I./lua-5.5.0/src/ \
	-L./lua-5.5.0/src/ \
	-ldl -lpthread -llua -lm

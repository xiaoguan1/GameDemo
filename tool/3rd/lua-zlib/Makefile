CC = gcc
CFLAGS = -O3 -fPIC -Wall -DNDEBUG
LUADIR = ../../../skynet/3rd/lua/
TARGET = ../../cplugins-so/zlib.so

.PHONY : all clean

all : $(TARGET)

$(TARGET) : lua_zlib.c
	$(CC) $(CFLAGS) -shared -o $@ -I$(LUADIR) $^ -lz

clean :
	rm -f $(TARGET)
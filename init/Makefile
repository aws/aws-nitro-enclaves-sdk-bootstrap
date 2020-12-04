CC       = gcc
C_FLAGS := -Wall -Wextra -Werror -O2

all: init

init: init.c
	$(CC) $(C_FLAGS) -o $@ $< -static -static-libgcc -flto
	strip --strip-all $@

clean:
	rm init

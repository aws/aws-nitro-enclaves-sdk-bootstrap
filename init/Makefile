
ARCH_aarch64	               = aarch64
C_FLAGS                       := -Wall -Wextra -Werror -O2
CC                            := gcc
DEFAULT_AARCH64_CROSS_COMPILER = /usr/bin/aarch64-linux-gnu-
HOST_MACHINE                   = $(shell uname -m)
BUILD_ARCH                    ?= $(HOST_MACHINE)


ifeq ($(BUILD_ARCH),$(ARCH_aarch64))
	ifndef CROSS_COMPILE
		ifneq ($(BUILD_ARCH),$(HOST_MACHINE))
			CROSS_COMPILE=$(DEFAULT_AARCH64_CROSS_COMPILER)
		endif
	endif
endif

all: init

init: init.c
	$(CROSS_COMPILE)$(CC) $(C_FLAGS) -o $@ $< -static -static-libgcc -flto
	$(CROSS_COMPILE)strip --strip-all $@

clean:
	rm -f init

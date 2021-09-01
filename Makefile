# Copyright 2019-2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

BUILDDIR                      ?= $(abspath build)
OUTDIR                        ?= $(abspath blobs)
ARCH_x86_64                    = x86_64
ARCH_aarch64                   = aarch64
LINUX_aarch64                  = arm64
KERN_IMAGE_x86_64              = bzImage
KERN_IMAGE_aarch64             = Image
CONFIG_TEMPLATE                = configs/microvm-kernel-config-
DEFAULT_AARCH64_CROSS_COMPILER = /usr/bin/aarch64-linux-gnu-
HOST_MACHINE                   = $(shell uname -m)
BUILD_ARCH                    ?= $(HOST_MACHINE)

CONFIG=$(CONFIG_TEMPLATE)$(BUILD_ARCH)

ifeq ($(BUILD_ARCH),$(ARCH_x86_64))
	KERN_IMAGE=$(KERN_IMAGE_x86_64)
	ARCH=$(ARCH_x86_64)
else ifeq ($(BUILD_ARCH),$(ARCH_aarch64))
	KERN_IMAGE=$(KERN_IMAGE_aarch64)
	ifndef CROSS_COMPILE
		ifneq ($(BUILD_ARCH),$(HOST_MACHINE))
			CROSS_COMPILE=$(DEFAULT_AARCH64_CROSS_COMPILER)
		endif
	endif
	ARCH=$(LINUX_aarch64)
endif

.PHONY: all blobs
all: blobs
blobs: $(OUTDIR)/nsm.ko $(OUTDIR)/$(KERN_IMAGE) $(OUTDIR)/init

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(BUILDDIR)/linux.tar: linux-url $(BUILDDIR)
	curl -L $$(head -n1 linux-url) | unxz > $@

$(BUILDDIR)/linux.sign: linux-url $(BUILDDIR)
	curl -L $$(tail -n1 linux-url) > $@

$(BUILDDIR)/linux: $(BUILDDIR)/linux.tar $(BUILDDIR)/linux.sign
	mkdir -p $(BUILDDIR)/linux
	gpg2 --verify  $(BUILDDIR)/linux.sign $(BUILDDIR)/linux.tar
	tar -xf $(BUILDDIR)/linux.tar --strip-components 1 -C $(BUILDDIR)/linux

$(BUILDDIR)/linux/.config: $(BUILDDIR)/linux $(CONFIG)
	make ARCH=$(ARCH) KCONFIG_ALLCONFIG=$$(pwd)/$(CONFIG) -C $(BUILDDIR)/linux allnoconfig

$(BUILDDIR)/$(KERN_IMAGE): $(BUILDDIR)/linux $(BUILDDIR)/linux/.config
	make -j$(nprocs) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) -C $(BUILDDIR)/linux
	cp $(BUILDDIR)/linux/arch/$(ARCH)/boot/$(KERN_IMAGE) $@

$(OUTDIR)/$(KERN_IMAGE): $(BUILDDIR)/$(KERN_IMAGE) $(OUTDIR)
	cp $(BUILDDIR)/$(KERN_IMAGE) $(OUTDIR)/$(KERN_IMAGE)

# TODO: adding O= creates issues with the build, but now it builds in the nsm-driver folder instead
# TODO: ideally this should be built in-tree to allow disabling modules in kernel altogether
$(OUTDIR)/nsm.ko: $(BUILDDIR)/$(KERN_IMAGE) $(OUTDIR)
	make ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) -C $(BUILDDIR)/linux M=$(PWD)/nsm-driver
	cp $(PWD)/nsm-driver/nsm.ko $(OUTDIR)/nsm.ko

$(OUTDIR)/init:  $(OUTDIR)
	make  BUILD_ARCH=$(BUILD_ARCH) CROSS_COMPILE=$(CROSS_COMPILE) -C $(PWD)/init
	cp $(PWD)/init/init $(OUTDIR)

clean:
	make -C $(BUILDDIR)/linux M=$(PWD)/nsm-driver clean
	make -C $(PWD)/init clean
	rm -rf $(BUILDDIR)/*

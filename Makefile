# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

BUILDDIR ?= $(abspath build)
OUTDIR   ?= $(abspath blobs)

.PHONY: all blobs
all: blobs 
blobs: $(OUTDIR)/nsm.ko $(OUTDIR)/bzImage

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(BUILDDIR)/linux.tar: linux-url $(BUILDDIR)
	curl -L $$(head -n1 linux-url) | unxz > $@

$(BUILDDIR)/linux.sign: linux-url $(BUILDDIR)
	curl -L $$(tail -n1 linux-url) > $@

$(BUILDDIR)/linux: $(BUILDDIR)/linux.tar $(BUILDDIR)/linux.sign
	gpg2 --verify  $(BUILDDIR)/linux.sign $(BUILDDIR)/linux.tar
	tar -xf $(BUILDDIR)/linux.tar --one-top-level=linux --strip-components 1 -C $(BUILDDIR)

$(BUILDDIR)/linux/.config: $(BUILDDIR)/linux microvm-kernel-config-x86_64
	make KCONFIG_ALLCONFIG=$$(pwd)/microvm-kernel-config-x86_64 -C $(BUILDDIR)/linux allnoconfig

$(BUILDDIR)/bzImage: $(BUILDDIR)/linux $(BUILDDIR)/linux/.config
	make -j$(nprocs) -C $(BUILDDIR)/linux
	cp $(BUILDDIR)/linux/arch/x86_64/boot/bzImage $@

$(OUTDIR)/bzImage: $(BUILDDIR)/bzImage $(OUTDIR)
	cp $(BUILDDIR)/bzImage $(OUTDIR)/bzImage

# TODO: adding O= creates issues with the build, but now it builds in the nsm-driver folder instead
# TODO: ideally this should be built in-tree to allow disabling modules in kernel altogether
$(OUTDIR)/nsm.ko: $(BUILDDIR)/bzImage $(OUTDIR)
	make -C $(BUILDDIR)/linux M=$(PWD)/nsm-driver
	cp $(PWD)/nsm-driver/nsm.ko $(OUTDIR)/nsm.ko

clean:
	make -C $(BUILDDIR)/linux M=$(PWD)/nsm-driver clean
	rm -rf $(BUILDDIR)/*

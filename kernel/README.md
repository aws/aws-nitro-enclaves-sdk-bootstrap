# kernel

Tooling and patches used to reproducibly build the latest LTS kernels and nitro secure module driver kernel module used by [aws-nitro-enclaves-cli](https://github.com/aws/aws-nitro-enclaves-cli).

These binaries are used by default by [aws-nitro-enclaves-cli](https://github.com/aws/aws-nitro-enclaves-cli) to build enclave image files (EIFs).

## How to build

You can generate the kernel, its final configuration file, and the compatible loadable module for the nitro secure module driver using [Nix](https://nixos.org/download.html) by running the command:

```
nix-build
```

This will produce the following results:

For `aarch64`:
```
result
├── Image
├── Image.config
└── nsm.ko
```

For `x86_64`:
```
result
├── bzImage
├── bzImage.config
└── nsm.ko
```

#### Limiting resources for the build

Kernel builds can be quite resource hungry, and nix building a kernel can exhaust your resources depending on your build machine.
To limit the number of parallel derivations that get evaluated use `--max-jobs <n>`.
To limit the amount of cores used for compilation use `--cores <m>` (think of this as your `make -j <m>` when building natively.

Example I used to build on an machine with 16GiB of ram and 8 cores:

```
nix-build --max-jobs 1 --cores 6 default.nix
```

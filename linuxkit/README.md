# linuxkit

Tooling and patches used to reproducibly build the linuxkit used by [aws-nitro-enclaves-cli](https://github.com/aws/aws-nitro-enclaves-cli).

Linuxkit gets used by [aws-nitro-enclaves-cli](https://github.com/aws/aws-nitro-enclaves-cli) to create the ramdisk images for Enclave Image Files. These image files are needed in order to run an application within an [AWS Nitro Enclave](https://docs.aws.amazon.com/enclaves/latest/user/nitro-enclave.html).

## How to build

You can generate the patched linuxkit executable using [Nix](https://nixos.org/download.html) by running the command:

```
nix-build
```

This will produce `result/bin/linuxkit` executable.

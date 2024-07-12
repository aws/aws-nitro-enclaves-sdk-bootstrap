## Bootstrap for AWS Nitro Enclaves

This project builds the kernel, nsm driver and bootstrap process for AWS Nitro Enclaves.

> [!NOTE]
> This project is currently in a transition phase updating the way the binaries are built and getting them setup to modern base versions.
> During the transition we retain the way the binaries were build before and adding new infrastructure to build newer versions of the binaries.
> As such we have already added a way to build `linuxkit` and newer kernels under `linuxkit/` and `kernel/`. These new variants of the binaries are not yet
> integrated with the top-level makefile. Please refer to their local readme files for instructions on how to build from these new variants ([linuxkit](linuxkit/README.md) and [kernel](kernel/README.md))

The referenced kernel in the 'linux-url' file is an example that can be used for building an enclave image. The kernel corresponding to the enclave image blobs in https://github.com/aws/aws-nitro-enclaves-cli/tree/main/blobs is based on the v4.14 Amazon Linux kernel - https://github.com/amazonlinux/linux/tree/amazon-4.14.y/master; it is different than the kernel mentioned in 'linux-url'.

### Prerequisites

The kernel download step requires setting up gpg2 with the kernel developer
keys. Instructions are available [here](https://www.kernel.org/category/signatures.html).

For Debian / Ubuntu systems, install build prequisites:
```
sudo apt-get install build-essential libncurses-dev bison flex libssl-dev libelf-dev gnupg2
```

For Amazon Linux 2 / Fedora / RHEL / CentOS install build prequisites:
```
sudo yum group install "Development Tools" 
```

## Build

The project can be built inside a Docker container to avoid installing toolchains and other packages
on your local device.

For example, to build for aarch64 run:

```
docker build --build-arg BUILD_ARCH=aarch64 .
```

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This project is licensed under the Apache-2.0 License.


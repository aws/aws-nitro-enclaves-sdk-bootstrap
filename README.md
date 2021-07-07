## Bootstrap for AWS Nitro Enclaves

This project builds the kernel, nsm driver and bootstrap process for AWS Nitro Enclaves.

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

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This project is licensed under the Apache-2.0 License.


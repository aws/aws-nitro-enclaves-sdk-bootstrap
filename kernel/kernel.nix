{ pkgs ? (import ../nixpkgs.nix) { } }:
let
  arch = pkgs.stdenv.hostPlatform.uname.processor;

  kern_arch = (
    if arch == "aarch64" then
      "arm64"
    else if arch == "x86_64" then
      "x86_64"
    else
      abort "Unsupported architecture '${arch}'"
    );

  kern_image = (
    if arch == "aarch64" then
      "Image"
    else if arch == "x86_64" then
      "bzImage"
    else
      abort "Unsupported architecture '${arch}'"
    );

  kern_config = (
    if arch == "aarch64" then
      ./microvm-kernel-config-aarch64
    else if arch == "x86_64" then
      ./microvm-kernel-config-x86_64
    else
      abort "Unsupported architecture '${arch}'"
    );
in
pkgs.stdenv.mkDerivation rec {
  pname = "nitro-enclaves-kernel";
  version = "6.6.62";

  depsBuildBuild = with pkgs.pkgsBuildBuild; [
    gcc
  ];

  nativeBuildInputs = with pkgs.buildPackages; [
    git
    gcc
    flex
    bison
    elfutils
    openssl
    bc
    perl
    gawk
  ];

  src = pkgs.fetchFromGitHub {
    owner = "gregkh";
    repo = "linux";
    rev = "v${version}";
    sha256 = "sha256-oWuFnRkeB6s+5C2L2pD2Ef4GXdFFsodJLbpPDmQm1sY=";
  };

  files = [
    kern_config
  ];

  patches = [
    # This one can be dropped with linux >= v6.8 as it is included
    # in upstream linux kernels starting with v6.8
    ./nsm.patch
    # Fixes an issue where virtio-vsock goes into a deadlock between
    # parent and enclave. Can be removed once it's in upstream stable
    # and we rebased.
    ./0001-vsock-virtio-Remove-queued_replies-pushback-logic.patch
  ];

  configurePhase = ''
    ( cat $files; echo CONFIG_NSM=m ) > .config
  '';

  buildPhase = ''
    patchShebangs ./scripts/ld-version.sh
    export KBUILD_BUILD_TIMESTAMP="$(date -u -d @$SOURCE_DATE_EPOCH)"
    export KBUILD_BUILD_USER="nixbuild"
    export KBUILD_BUILD_HOST="nixbuilder"
    make olddefconfig ${kern_image} modules -j "$NIX_BUILD_CORES"
  '';

  installPhase = ''
    mkdir -p $out
    cp arch/${kern_arch}/boot/${kern_image} $out/
    cp drivers/misc/nsm.ko $out/
    cp .config $out/${kern_image}.config
  '';

  # The Nitro Enclaves loader on aarch64 loads the target image at the image provided target address.
  # Recent Linux kernel versions introduced a special value of "0" to indicate that the boot loader
  # should determine a random address instead. Provide the loader with an appropriate address here,
  # so we don't load the kernel at address 0 where it can not execute.
  #
  # This writes the `text_offset` address of the Image file header to 2 MiB.
  fixupPhase = if arch == "aarch64" then
    ''
      printf "\x00\x00\x20\x00\x00\x00\x00\x00" | dd of=$out/Image bs=1 count=8 seek=8 conv=notrunc
    ''
    else
    '' ''
  ;

  meta = {
    description = "Linux Kernel ${version} for Nitro Enclaves";
    homepage = https://kernel.org;
    license = "gpl2Only";
  };
}

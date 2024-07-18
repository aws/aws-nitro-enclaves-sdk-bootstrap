{
  pkgs ? import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/refs/tags/24.05.tar.gz";
    sha256 = "sha256:1lr1h35prqkd1mkmzriwlpvxcb34kmhc9dnr48gkm8hh089hifmx";
  }) {}
}:
pkgs.buildGoModule rec {
  pname = "linuxkit";
  version = "1.2.0";

  src = pkgs.fetchFromGitHub {
    owner = "linuxkit";
    repo = "linuxkit";
    rev = "v${version}";
    sha256 = "sha256-PrHGIP74mDt+mJDRaCsroiJ4QEW4/tzgsZI2JlZ8TEA=";
  };

  buildInputs = with pkgs; [
    musl
  ];

  nativeCheckInputs = with pkgs; [
    git
  ];

  vendorHash = null;

  modRoot = "./src/cmd/linuxkit";

  ldflags = [
    "-s"
    "-w"
    "-X github.com/linuxkit/linuxkit/src/cmd/linuxkit/version.Version=${version}+"
    "-linkmode external"
    "-extldflags '-static -L${pkgs.musl}/lib'"
    "--buildmode pie"
  ];

  patches = [
    ./0001-build-Allow-to-ad-a-directory-prefix-when-unpacking-.patch
    ./0002-output-Add-new-type-kernel-initrd-nogz.patch
    ./0003-Fix-output-image-duplicate-entries.patch
  ];


}

{
  pkgs ? import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/refs/tags/23.05.tar.gz";
    sha256 = "sha256:10wn0l08j9lgqcw8177nh2ljrnxdrpri7bp0g7nvrsn9rkawvlbf";
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

  CGO_ENABLED = 0;

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

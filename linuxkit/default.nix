{
  pkgs ? import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/refs/tags/23.05.tar.gz";
    sha256 = "sha256:10wn0l08j9lgqcw8177nh2ljrnxdrpri7bp0g7nvrsn9rkawvlbf";
  }) {}
}:
pkgs.buildGoModule rec {
  pname = "linuxkit";
  version = "0.8";
  gitcommit = "b710224cdf9a8425a7129cdcb84fc1af00f926d7";

  src = pkgs.fetchFromGitHub {
    owner = "linuxkit";
    repo = "linuxkit";
#    rev = "v${version}";
    rev = "${gitcommit}";
    sha256 = "sha256-UqPX+r3by7v+PL+/xUiSZVsB7EO7VUr3aDfVIhQDEgY=";
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
    ./0001-Add-prefix-build-option.patch
    ./0002-Remove-gzip-cpio-wrapper.patch
    ./0003-Fix-output-image-duplicate-entries.patch
  ];


}

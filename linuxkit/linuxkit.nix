{ pkgs ? (import ../nixpkgs.nix) { } }:
pkgs.buildGoModule rec {
  pname = "linuxkit";
  version = "1.5.2";

  src = pkgs.fetchFromGitHub {
    owner = "linuxkit";
    repo = "linuxkit";
    rev = "v${version}";
    sha256 = "sha256-M/M4m/vsvvtSDnNNy8p6x+xpv1QmVzyfPRf/BNBX7zA=";
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

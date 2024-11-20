{ pkgs ? (import ../nixpkgs.nix) { } }:
pkgs.stdenv.mkDerivation rec {
  name = "nitro-enclaves-init";

  nativeBuildInputs = with pkgs; [
    gcc
    glibc.static
  ];

  src = ./.;

  buildPhase = ''
    gcc -Wall -Wextra -Werror -O2 -o init init.c -static -static-libgcc -flto
    strip --strip-all init
  '';

  installPhase = ''
    mkdir -p $out
    cp init $out/
  '';
}

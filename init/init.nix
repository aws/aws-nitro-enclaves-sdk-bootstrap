{ pkgs ? (import ../nixpkgs.nix) { } }:
pkgs.stdenv.mkDerivation rec {
  name = "nitro-enclaves-init";

  nativeBuildInputs = with pkgs.buildPackages; [
    gcc
  ];

  buildInputs = with pkgs; [
    glibc.static
  ];

  src = ./.;

  buildPhase = ''
    ${pkgs.stdenv.cc.targetPrefix}gcc -Wall -Wextra -Werror -O2 -o init init.c -static -static-libgcc -flto
    ${pkgs.stdenv.cc.targetPrefix}strip --strip-all init
  '';

  installPhase = ''
    mkdir -p $out
    cp init $out/
  '';
}

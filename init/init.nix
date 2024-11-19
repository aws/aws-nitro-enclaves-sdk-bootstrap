{ pkgs ? (import ../nixpkgs.nix) { } }:
pkgs.stdenv.mkDerivation rec {
  name = "nitro-enclaves-init";

  src = ./.;

  buildPhase = ''
    $CC -Wall -Wextra -Werror -O2 -o init init.c -flto
    $STRIP --strip-all init
  '';

  installPhase = ''
    mkdir -p $out
    cp init $out/
  '';
}

{ pkgs ? (import ./nixpkgs.nix) { } }:
let
  arch = pkgs.stdenv.hostPlatform.uname.processor;
in
rec {
  init = pkgs.pkgsStatic.callPackage ./init/init.nix { };

  kernel = pkgs.callPackage ./kernel/kernel.nix { };

  linuxkit = pkgs.pkgsStatic.callPackage ./linuxkit/linuxkit.nix { };


  all = pkgs.runCommandNoCC "enclaves-blobs-${arch}" { } ''
    mkdir -p $out/${arch}
    cp -r ${init}/* $out/${arch}/
    cp -r ${kernel}/* $out/${arch}/
    cp -r ${linuxkit}/bin/* $out/${arch}/
  '';
}

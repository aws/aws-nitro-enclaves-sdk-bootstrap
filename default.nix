let
  nixpkgs = import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/refs/tags/24.05.tar.gz";
    sha256 = "sha256:1lr1h35prqkd1mkmzriwlpvxcb34kmhc9dnr48gkm8hh089hifmx";
  }) { };

  arch = nixpkgs.stdenv.hostPlatform.uname.processor;
in
rec {
  init = nixpkgs.callPackage ./init/init.nix { };

  kernel = nixpkgs.callPackage ./kernel/kernel.nix { };

  linuxkit = nixpkgs.callPackage ./linuxkit/linuxkit.nix { };


  all = nixpkgs.runCommandNoCC "enclaves-blobs-${arch}" { } ''
    mkdir -p $out/${arch}
    cp -r ${init}/* $out/${arch}/
    cp -r ${kernel}/* $out/${arch}/
    cp -r ${linuxkit}/bin/* $out/${arch}/
  '';
}

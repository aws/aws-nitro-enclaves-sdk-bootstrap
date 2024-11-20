let
  nixpkgs = (import ./nixpkgs.nix) { };

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

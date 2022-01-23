final: prev: rec {
  # Notes:
  #
  # When determining a SHA256, use this to set a fake one until we know
  # the real value:
  #
  #    vendorSha256 = nixpkgs.lib.fakeSha256;
  #

  devShell = prev.callPackage ./devshell.nix { };
  libflightplan = prev.callPackage ./package.nix { };

  # zig we want to be the latest nightly since 0.9.0 is not released yet.
  zig = final.zigpkgs.master.latest;
}

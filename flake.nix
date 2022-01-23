{
  description = "libflightplan";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig.url = "github:roarkanize/zig-overlay";

    # Used for shell.nix
    flake-compat = { url = github:edolstra/flake-compat; flake = false; };

    # Dependencies we track using flake.lock
    zig-libxml2-src = {
      url = "https://github.com/mitchellh/zig-libxml2.git";
      flake = false;
      submodules = true;
      type = "git";
      ref = "main";
    };
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    let
      overlays = [
        # Our repo overlay
        (import ./nix/overlay.nix)

        # Other overlays
        (final: prev: {
          zigpkgs = inputs.zig.packages.${prev.system};
          zig-libxml2-src = inputs.zig-libxml2-src;
        })
      ];

      # Our supported systems are the same supported systems as the Zig binaries
      systems = builtins.attrNames inputs.zig.packages;
    in flake-utils.lib.eachSystem systems (system:
      let pkgs = import nixpkgs { inherit overlays system; };
      in rec {
        devShell = pkgs.devShell;
        packages.libflightplan = pkgs.libflightplan;
        defaultPackage = packages.libflightplan;
      }
    );
}

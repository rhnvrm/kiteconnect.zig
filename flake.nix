{
  description = "kiteconnect.zig development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ zig-overlay.overlays.default ];
        pkgs = import nixpkgs { inherit system overlays; };
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            zigpkgs."0.15.2"
            zls
            just
            git
            jq
          ];
          shellHook = ''
            export ZIG_GLOBAL_CACHE_DIR="$PWD/.zig-cache-global"
            echo "kiteconnect.zig dev shell"
            zig version
          '';
        };
      });
}

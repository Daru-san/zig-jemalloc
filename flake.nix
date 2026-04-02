{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    zig-overlay.url = "github:mitchellh/zig-overlay";
    zls = {
      url = "github:zigtools/zls";
      inputs.zig-overlay.follows = "zig-overlay";
    };
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake = { };
      systems = [
        "x86_64-linux"
      ];
      perSystem =
        {
          pkgs,
          lib,
          system,
          ...
        }:
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                zigpkgs = inputs.zig-overlay.packages.${prev.system} // inputs.zls.packages.${prev.system};
              })
            ];
          };
          formatter = pkgs.nixfmt;
          devShells.default = pkgs.mkShell {
            buildInputs =
              (with pkgs; [
                pkg-config
                jemalloc
              ])
              ++ (with pkgs.zigpkgs; [
                master
                zls
              ]);
            LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.jemalloc ];
          };
        };
    };
}

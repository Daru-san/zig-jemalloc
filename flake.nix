{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      flake-parts,
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
          ...
        }:
        {
          formatter = pkgs.nixfmt;
          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              pkg-config
              autoconf
              zig
              zls
              gnumake
            ];
          };
        };
    };
}

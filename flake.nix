{
  description = "Custom packages and overrides on top of nixpkgs";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f system);
    in
    {
      overlays.default = import ./overlay.nix;

      legacyPackages = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = self.legacyPackages.${system};
          names = lib.attrNames (self.overlays.default pkgs pkgs);
        in
        lib.filterAttrs (_: lib.isDerivation) (lib.getAttrs names pkgs)
      );

      checks = self.packages;

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}

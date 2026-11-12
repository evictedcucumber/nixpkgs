{
  description = "Custom packages and overrides on top of nixpkgs";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      pkgs = self.legacyPackages.${system};
    in
    {
      overlays.default = import ./overlay.nix;

      nixosModules = {
        helium = ./modules/nixos/helium.nix;
        default = self.nixosModules.helium;
      };

      homeModules = {
        helium = ./modules/home-manager/helium.nix;
        default = self.homeModules.helium;
      };

      legacyPackages.${system} = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };

      packages.${system} = lib.filterAttrs (_: lib.isDerivation) (
        lib.getAttrs (lib.attrNames (self.overlays.default pkgs pkgs)) pkgs
      );

      checks = self.packages;

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}

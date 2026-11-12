{
  description = "Custom packages and overrides on top of nixpkgs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
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

      checks.${system} =
        self.packages.${system}
        // import ./modules/checks.nix {
          inherit
            self
            nixpkgs
            home-manager
            pkgs
            ;
        };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}

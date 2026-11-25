{
  description = "Custom packages and overrides on top of nixpkgs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
    }:
    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      pkgs = self.legacyPackages.${system};
    in
    {
      overlays.default = lib.composeManyExtensions [
        (import ./rust/overlay.nix)
        (import ./overlay.nix)
      ];
      overlays.stable = import ./overlay-stable.nix nixpkgs-stable;

      nixosModules = {
        helium = ./modules/nixos/helium.nix;
        nginx-proxy-manager = ./modules/nixos/nginx-proxy-manager.nix;
        default = self.nixosModules.helium;
      };

      homeModules = {
        helium = ./modules/home-manager/helium.nix;
        default = self.homeModules.helium;
      };

      legacyPackages.${system} = import nixpkgs {
        inherit system;
        overlays = [
          self.overlays.default
          self.overlays.stable
        ];
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
        }
        // {
          rust-toolchain-for = import ./checks/rust-toolchain-for pkgs;
          rust-toolchain-build = import ./checks/rust-toolchain-build pkgs;
        };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}

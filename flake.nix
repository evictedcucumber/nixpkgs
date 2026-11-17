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
      lib = import ./lib.nix { inherit self nixpkgs; };

      overlays.default = import ./overlay.nix;
      overlays.stable = import ./overlay-stable.nix nixpkgs-stable;

      nixosModules = nixpkgs.nixosModules // {
        helium = ./modules/nixos/helium.nix;
        default = self.nixosModules.helium;
      };

      homeModules = {
        helium = ./modules/home-manager/helium.nix;
        default = self.homeModules.helium;
      };

      # Every system upstream exposes, so inputs that follow this flake can use any of them.
      legacyPackages = lib.mapAttrs (
        system: _:
        import nixpkgs {
          inherit system;
          overlays = [
            self.overlays.default
            self.overlays.stable
          ];
        }
      ) nixpkgs.legacyPackages;

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
          # `import` of this source must match legacyPackages and keep the caller's overlays and config.
          default-nix =
            let
              imported = import ./. {
                inherit system;
                overlays = [ (final: _: { fromCaller = final.helium; }) ];
                config.allowUnfree = true;
              };
            in
            assert imported.fromCaller.drvPath == pkgs.helium.drvPath;
            assert imported.stable.hello.drvPath == pkgs.stable.hello.drvPath;
            assert imported.config.allowUnfree;
            pkgs.runCommand "default-nix" { } "touch $out";
        };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}

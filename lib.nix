# nixpkgs' lib, with `nixosSystem` adding this repo's packages and modules to every host as if built in.
{ self, nixpkgs }:
let
  builtin =
    { lib, options, ... }:
    {
      imports = [ self.nixosModules.helium ];
      config = lib.mkMerge [
        {
          # A host that brings its own pkgs got them from `import nixpkgs`, which already applies these.
          nixpkgs.overlays = lib.mkIf (!options.nixpkgs.pkgs.isDefined) [
            self.overlays.default
            self.overlays.stable
          ];
        }
        (lib.optionalAttrs (options ? home-manager.sharedModules) {
          home-manager.sharedModules = [ self.homeModules.helium ];
        })
      ];
    };
in
nixpkgs.lib.extend (
  final: prev: {
    nixosSystem = args: prev.nixosSystem (args // { modules = [ builtin ] ++ args.modules or [ ]; });
  }
)

final: prev:
let
  inherit (prev) lib;
  newPackages = lib.mapAttrs (name: _: final.callPackage ./pkgs/${name}/package.nix { }) (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./pkgs)
  );
in
newPackages // import ./overrides.nix final prev

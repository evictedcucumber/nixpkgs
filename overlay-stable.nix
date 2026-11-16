# Plain stable nixpkgs as `pkgs.stable`, without this repo's packages or overrides.
nixpkgs-stable: final: prev: {
  stable = import nixpkgs-stable {
    inherit (prev.stdenv.hostPlatform) system;
    # Only these keys: the full evaluated unstable config fails stable's option types.
    config = prev.lib.intersectAttrs {
      allowUnfree = null;
      allowUnfreePredicate = null;
      permittedInsecurePackages = null;
      allowInsecurePredicate = null;
    } prev.config;
  };
}

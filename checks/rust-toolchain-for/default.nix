# Evaluate rustToolchainFor both ways without building or downloading a toolchain.
pkgs:
let
  pinned = pkgs.rustToolchainFor ./pinned;
  unpinned = pkgs.rustToolchainFor ./.;
in
assert pinned.version == "1.85.0";
assert unpinned.drvPath == pkgs.rust-bin.stable.latest.default.drvPath;
pkgs.writeText "rust-toolchain-for" (
  builtins.unsafeDiscardStringContext ''
    ${pinned.drvPath}
    ${unpinned.drvPath}
  ''
)

# Evaluate rustToolchainFor without building a toolchain.
pkgs:
let
  inherit (pkgs) lib;
  latestStable = lib.last (
    lib.sort (a: b: lib.versionOlder a b) (
      lib.filter (channel: builtins.match "1\\.[0-9]+\\.[0-9]+" channel != null) (
        lib.attrNames (lib.importJSON ../../rust/manifests.json)
      )
    )
  );
  pinned = pkgs.rustToolchainFor ./pinned;
  unpinned = pkgs.rustToolchainFor ./.;
  nightly = pkgs.rustToolchainFor ./nightly;
in
assert pinned.version == "1.85.0";
assert unpinned.version == latestStable;
pkgs.writeText "rust-toolchain-for" (
  builtins.unsafeDiscardStringContext ''
    ${pinned.drvPath}
    ${unpinned.drvPath}
    ${nightly.drvPath}
  ''
)

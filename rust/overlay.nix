# `pkgs.rustToolchainFor`: Rust toolchains from official dist manifests pinned in manifests.json.
final: prev:
let
  inherit (prev) lib;
  manifests = lib.importJSON ./manifests.json;
  stable = builtins.sort (a: b: builtins.compareVersions a b > 0) (
    lib.filter (channel: builtins.match "1\\.[0-9]+\\.[0-9]+" channel != null) (lib.attrNames manifests)
  );

  resolve =
    channel:
    let
      minor = builtins.match "(1\\.[0-9]+)" channel;
      found =
        if channel == "stable" then
          lib.head stable
        else if minor != null then
          lib.findFirst (lib.hasPrefix "${channel}.") null stable
        else
          channel;
    in
    if found != null && manifests ? ${found} then
      found
    else
      throw "rust channel '${channel}' is not in rust/manifests.json; use 1.x.y, 1.x, stable, or nightly-YYYY-MM-DD, and add missing ones with rust/update.sh <channel>";

  manifestUrl =
    channel:
    let
      nightly = builtins.match "nightly-(.*)" channel;
    in
    if nightly != null then
      "https://static.rust-lang.org/dist/${lib.head nightly}/channel-rust-nightly.toml"
    else
      "https://static.rust-lang.org/dist/channel-rust-${channel}.toml";

  readToolchainFile =
    file:
    let
      text = builtins.readFile file;
    in
    if lib.hasInfix "[toolchain]" text then
      (builtins.fromTOML text).toolchain
    else
      { channel = lib.trim text; };
in
{
  # The toolchain from `dir`'s rust-toolchain.toml or rust-toolchain file, else the latest stable.
  rustToolchainFor =
    dir:
    let
      file = lib.findFirst builtins.pathExists null [
        (dir + "/rust-toolchain.toml")
        (dir + "/rust-toolchain")
      ];
      toolchain = if file == null then { } else readToolchainFile file;
      channel = resolve (toolchain.channel or "stable");
    in
    final.callPackage ./toolchain.nix { } {
      manifest = builtins.fromTOML (
        builtins.readFile (
          builtins.fetchurl {
            url = manifestUrl channel;
            sha256 = manifests.${channel};
          }
        )
      );
      components = toolchain.components or [ ];
      targets = toolchain.targets or [ ];
      profile = toolchain.profile or "default";
    };
}

# Helpers on top of oxalica/rust-overlay's `rust-bin`.
final: prev: {
  # The toolchain from `dir`'s rust-toolchain.toml or rust-toolchain file, else the latest stable.
  rustToolchainFor =
    dir:
    let
      file = prev.lib.findFirst builtins.pathExists null [
        (dir + "/rust-toolchain.toml")
        (dir + "/rust-toolchain")
      ];
    in
    if file == null then
      final.rust-bin.stable.latest.default
    else
      final.rust-bin.fromRustupToolchainFile file;
}

# A Rust toolchain in one derivation, built from the official dist tarballs listed in `manifest`.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
}:
{
  manifest,
  components ? [ ],
  targets ? [ ],
  profile ? "default",
}:
let
  host = "x86_64-unknown-linux-gnu";

  resolve = name: manifest.renames.${name}.to or name;
  lookup = name: target: manifest.pkg.${resolve name}.target.${target} or null;
  hostLookup = name: if lookup name host != null then lookup name host else lookup name "*";
  isAvailable = info: info != null && info.available;

  profileMembers =
    manifest.profiles.${profile} or (throw "rust profile '${profile}' does not exist in this manifest");
  requested =
    map (name: {
      inherit name;
      info = hostLookup name;
    }) components
    ++ map (target: {
      name = "rust-std for ${target}";
      info = lookup "rust-std" target;
    }) targets;
  fromProfile = lib.filter isAvailable (map hostLookup profileMembers);
  fromRequest = map (
    c:
    if isAvailable c.info then
      c.info
    else
      throw "rust component '${c.name}' is not available in this manifest"
  ) requested;

  srcs = map (
    info:
    fetchurl {
      url = info.xz_url;
      sha256 = info.xz_hash;
    }
  ) (lib.unique (fromProfile ++ fromRequest));
in
stdenv.mkDerivation {
  pname = "rust";
  version = lib.head (lib.splitString " " manifest.pkg.rust.version);
  inherit srcs;

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    stdenv.cc.cc.lib
    zlib
  ];

  installPhase = ''
    for src in $srcs; do
      dir=$(mktemp -d)
      tar -xf "$src" -C "$dir" --strip-components=1
      bash "$dir/install.sh" --prefix="$out" --disable-ldconfig
      rm -r "$dir"
    done
  '';

  meta = {
    description = "Rust toolchain from the official dist manifest";
    homepage = "https://www.rust-lang.org";
    license = [
      lib.licenses.mit
      lib.licenses.asl20
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "rustc";
  };
}

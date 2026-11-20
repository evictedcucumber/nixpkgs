# Build the latest stable toolchain, then compile and run a small crate with it.
pkgs:
pkgs.runCommandCC "rust-toolchain-build" { nativeBuildInputs = [ (pkgs.rustToolchainFor ./.) ]; } ''
  export HOME=$TMPDIR
  cargo new --vcs none hello
  cd hello
  cargo build --offline
  [ "$(./target/debug/hello)" = "Hello, world!" ]
  touch $out
''

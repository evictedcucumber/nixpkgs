# `import` this source like nixpkgs: the locked nixpkgs with this repo's overlays applied first.
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  input = name: builtins.fetchTree lock.nodes.${lock.nodes.root.inputs.${name}}.locked;
in
{
  overlays ? [ ],
  ...
}@args:
import (input "nixpkgs") (
  args
  // {
    overlays = [
      (import ./overlay.nix)
      (import ./overlay-stable.nix (input "nixpkgs-stable"))
    ]
    ++ overlays;
  }
)

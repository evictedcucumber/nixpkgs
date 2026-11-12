# nixpkgs

My own custom nixpkgs: packages nixpkgs lacks, and overrides of ones it has. It tracks `nixos-unstable`, and CI updates nixpkgs and the packages daily at 01:00 SAST.

Only `x86_64-linux` is supported.

## Outputs

| Output | What it is |
| --- | --- |
| `legacyPackages.x86_64-linux` | All of nixpkgs, with this repo's packages and overrides applied |
| `overlays.default` | The same additions and overrides, as an overlay for your own nixpkgs |
| `packages.x86_64-linux` | Only the packages this repo adds or overrides |

## Usage

Add it as a flake input:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  my-nixpkgs.url = "github:evictedcucumber/nixpkgs";
};
```

Then pick one of the two ways below.

### Use it in place of nixpkgs

Take the package set straight from `legacyPackages`. You get this repo's nixpkgs pin, updated daily, so you don't need your own `nixpkgs` input.

```nix
{
  inputs.my-nixpkgs.url = "github:evictedcucumber/nixpkgs";

  outputs =
    { my-nixpkgs, ... }:
    let
      pkgs = my-nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.hello ];
      };
    };
}
```

This instance has no `config` (such as `allowUnfree`). If you need one, use the overlay instead.

### Apply the overlay to your own nixpkgs

Keep your own nixpkgs pin and config, and add this repo's packages on top.

In a project:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    my-nixpkgs = {
      url = "github:evictedcucumber/nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, my-nixpkgs, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ my-nixpkgs.overlays.default ];
        config.allowUnfree = true;
      };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.hello ];
      };
    };
}
```

In a NixOS module, with `inputs` passed through `specialArgs`:

```nix
{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.my-nixpkgs.overlays.default ];
  environment.systemPackages = [ pkgs.hello ];
}
```

`inputs.nixpkgs.follows = "nixpkgs"` stops a second copy of nixpkgs from being fetched.

### Run a package directly

```bash
nix run github:evictedcucumber/nixpkgs#<package>
```

```bash
nix shell github:evictedcucumber/nixpkgs#<package>
```

### Get the latest updates

```bash
nix flake update my-nixpkgs
```

## Contributing

See [AGENTS.md](AGENTS.md) for the layout and how to add or override packages.

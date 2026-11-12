# nixpkgs

My own custom nixpkgs: packages nixpkgs lacks, and overrides of ones it has. Inputs and packages update daily.

## Usage

```nix
{
  inputs.my-nixpkgs.url = "github:evictedcucumber/nixpkgs";

  outputs = { nixpkgs, my-nixpkgs, ... }: {
    # Either use the full package set with everything applied:
    #   my-nixpkgs.legacyPackages.${system}.<pkg>
    # or apply the overlay to your own nixpkgs:
    #   import nixpkgs { inherit system; overlays = [ my-nixpkgs.overlays.default ]; }
  };
}
```

See [AGENTS.md](AGENTS.md) for the layout and how to add packages.

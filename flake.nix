{
  description = "verified-net: no_std network protocols in Rust, with hand-written specs and proofs in Lean (Aeneas)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    import-tree.url = "github:vic/import-tree";
    crane.url = "github:ipetkov/crane";

    # The verification toolchain. Charon is pinned by Aeneas; reuse it so the
    # LLBC format always matches. Aeneas keeps its own nixpkgs (nightly Rust).
    aeneas.url = "github:AeneasVerif/aeneas";
    charon.follows = "aeneas/charon";
  };

  # Every file under nix/ is a flake-parts module, named for what it provides.
  outputs =
    inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./nix);
}

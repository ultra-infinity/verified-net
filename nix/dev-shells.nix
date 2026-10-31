# `nix develop`: the verification toolchain, the pinned Rust nightly (also
# what `cargo build` uses here), Charon, Aeneas and Lean (through `elan`);
# and the formatter.
{
  perSystem =
    {
      pkgs,
      aeneasPkg,
      rustToolchain,
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          aeneasPkg
          rustToolchain
          pkgs.elan
          pkgs.gnumake
          pkgs.taplo
          pkgs.nixfmt
        ];
      };
      formatter = pkgs.nixfmt;
    };
}

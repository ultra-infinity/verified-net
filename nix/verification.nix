# Checks that the verification is reproducible: the Lean library is pinned
# to the Aeneas binary's commit, and the committed models are what the
# extraction produces from the Rust sources.
{
  perSystem =
    {
      pkgs,
      root,
      craneLib,
      aeneasPkg,
      rustToolchain,
      aeneasRev,
      ...
    }:
    {
      checks = {
        # The Lean `aeneas` library must come from the same commit as the
        # `aeneas` binary, otherwise the generated code may not typecheck.
        aeneas-pin = pkgs.runCommand "verified-net-check-aeneas-pin" { } ''
          if ! grep -q 'rev = "${aeneasRev}"' ${root + "/proofs/lakefile.toml"}; then
            echo 'ERROR: proofs/lakefile.toml does not require aeneas at ${aeneasRev}'
            echo '(the revision locked in flake.lock). Run `make aeneas-pin`.'
            exit 1
          fi
          touch $out
        '';

        # Re-run the extraction of every crate and make sure the committed
        # Lean models are up to date with the Rust sources. The extraction
        # writes only the generated files, so the hand-written specs and
        # proofs next to them compare equal.
        extraction = (craneLib.overrideToolchain rustToolchain).mkCargoDerivation {
          pname = "verified-net-check-extraction";
          version = "0.1.0";
          src = pkgs.lib.fileset.toSource {
            inherit root;
            fileset = pkgs.lib.fileset.unions [
              (root + "/Cargo.toml")
              (root + "/Cargo.lock")
              (root + "/Makefile")
              (root + "/crates")
              (root + "/proofs")
            ];
          };
          # crane vendors the crates.io dependencies (the sandbox has no
          # network); nothing is built ahead of the extraction.
          cargoArtifacts = null;
          doInstallCargoArtifacts = false;
          nativeBuildInputs = [
            aeneasPkg
            pkgs.gnumake
          ];
          buildPhaseCargoCommand = ''
            export HOME=$TMPDIR
            cp -r proofs proofs-committed
            make extract
            diff -ru proofs-committed proofs || {
              echo 'ERROR: generated Lean files are stale. Run `make extract`.'
              exit 1
            }
          '';
          installPhaseCommand = "touch $out";
        };
      };
    };
}

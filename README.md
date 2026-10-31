# verified-net

`no_std` network protocols in Rust, each formally verified against a
specification written by hand in Lean 4 from the protocol's standard.

The Rust code is translated to Lean with [Charon] and [Aeneas]. The
specification and the proofs that the translated code meets it are written
by hand, not generated.

| Protocol | Crate         | Standard | Lean library  |
|----------|---------------|----------|---------------|
| UDP      | `crates/udp`  | RFC 768  | `proofs/Udp`  |

## Layout

```
crates/<protocol>/      the Rust crate: no_std, no unsafe
proofs/<Lib>/           its Lean library:
  Types.lean, Funs.lean   the model Aeneas generates from the crate (do not edit)
  …                       the hand-written spec and proofs
proofs/lakefile.toml    one lean_lib per crate, Aeneas pinned to flake.lock
nix/                    flake-parts modules: crane build, checks, dev shell
```

## Building

Everything goes through Nix:

```sh
nix build .#udp          # build the crate (crane)
nix flake check          # clippy, tests, rustfmt, and that the committed
                         # Lean models match the Rust sources
nix develop              # Charon, Aeneas, the pinned Rust nightly, Lean (elan)
```

Inside `nix develop`:

```sh
make extract             # regenerate the Lean models from the Rust crates
make lean-deps           # fetch prebuilt Mathlib (once)
make verify              # check the models, specs and proofs
```

The first `nix develop` builds Charon and Aeneas from source, which takes a
while.

## Adding a protocol

1. `crates/<protocol>/`: a `#![no_std]` crate (the workspace picks up
   everything under `crates/`).
2. `Makefile`: add it to `CRATES` and set `LIB_<protocol>`.
3. `proofs/lakefile.toml`: add its `[[lean_lib]]`.
4. `make extract`, then write the spec and proofs next to the generated model.

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE) or
[MIT license](LICENSE-MIT), at your option.

[Charon]: https://github.com/AeneasVerif/charon
[Aeneas]: https://github.com/AeneasVerif/aeneas

# Rust → Charon (LLBC) → Aeneas → Lean pipeline. Run inside `nix develop`.

# Every crate that is verified, and the Lean library its model goes in
# (proofs/<Lib>/Types.lean, Funs.lean …). Next to the generated files, in
# the same library, are the hand-written spec and proofs.
CRATES   := udp
LIB_udp  := Udp

PROOFS := proofs
LLBC   := target/charon
FLAKE  := $(CURDIR)

# Everything in the crate is translated, including derived impls.
CHARON_FLAGS := --preset=aeneas

# Loops become structurally recursive functions, which the Aeneas proof
# tooling handles best.
AENEAS_FLAGS := -backend lean -split-files -loops-to-rec

.PHONY: all build test extract lean-deps verify aeneas-pin clean

all: extract verify

build:
	cargo build --workspace

test:
	cargo test --workspace

# Generate the Lean model of every crate.
extract: $(addprefix extract-,$(CRATES))

# `make extract-udp`: translate the crate to LLBC with Charon, then to Lean.
extract-%:
	charon cargo $(CHARON_FLAGS) --dest-file $(LLBC)/$*.llbc -- -p $*
	aeneas $(AENEAS_FLAGS) -subdir $(LIB_$*) -dest $(PROOFS) $(LLBC)/$*.llbc

# Download prebuilt Mathlib oleans (Aeneas depends on Mathlib).
lean-deps:
	cd $(PROOFS) && lake exe cache get

# Check the models, specs and proofs of every crate.
verify:
	cd $(PROOFS) && lake build $(foreach c,$(CRATES),$(LIB_$(c)))

# Point the Lean `aeneas` library at the commit of the `aeneas` binary
# locked in flake.lock.
aeneas-pin:
	rev=$$(nix eval --raw --impure --expr '(builtins.getFlake "$(FLAKE)").inputs.aeneas.rev') && \
	src=$$(nix eval --raw --impure --expr '(builtins.getFlake "$(FLAKE)").inputs.aeneas.outPath') && \
	sed -i "s/^rev = \".*\"/rev = \"$$rev\"/" $(PROOFS)/lakefile.toml && \
	cp $$src/backends/lean/lean-toolchain $(PROOFS)/lean-toolchain && \
	chmod u+w $(PROOFS)/lean-toolchain && \
	cd $(PROOFS) && lake update aeneas

clean:
	cargo clean
	rm -rf $(PROOFS)/.lake

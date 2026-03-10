#!/bin/bash
# Setup script for formal equivalence verification infrastructure.
# This builds Sail from source (for libsail) and the Isla plugin.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAIL_SRC="${SAIL_SRC:-$HOME/sail-github}"
ISLA_DIR="${ISLA_DIR:-$HOME/isla}"

echo "=== Setting up formal verification infrastructure ==="

# Activate opam environment
eval $(opam env 2>/dev/null) || true

# 1. Install OCaml dependencies for building Sail from source
echo "[1/4] Installing OCaml dependencies..."
opam install menhir base64 omd yojson ott lem pprint dune-site linksem --yes 2>&1 | tail -3

# 2. Build libsail from Sail source
echo "[2/4] Building libsail from $SAIL_SRC..."
cd "$SAIL_SRC"
dune build --release src/lib/libsail.cma 2>&1 | tail -5
dune install --release libsail 2>&1 | tail -3
echo "  libsail installed: $(ocamlfind list | grep libsail)"

# 3. Fix and build isla-sail plugin
echo "[3/4] Building isla-sail plugin..."
cd "$ISLA_DIR/isla-sail"

# Patch isla-sail for Sail 0.20.1 compatibility (Bindings module moved)
if ! grep -q "open Ast_compare" sail_plugin_isla.ml; then
    sed -i 's/^open Jib_util$/open Jib_util\nopen Ast_compare/' sail_plugin_isla.ml
    echo "  Applied Ast_compare patch to isla-sail"
fi

dune build --release 2>&1 | tail -3
echo "  Plugin built: $ISLA_DIR/isla-sail/_build/default/sail_plugin_isla.cmxs"

# 4. Build Isla (Rust)
echo "[4/4] Building Isla..."
cd "$ISLA_DIR"
cargo build --release 2>&1 | tail -3
echo "  Isla built: $ISLA_DIR/target/release/isla-footprint"

# 5. Build Sail binary from source (needed for plugin compatibility)
echo "[5/5] Building Sail binary..."
cd "$SAIL_SRC"
dune build --release src/bin/sail.exe 2>&1 | tail -3
echo "  Sail binary: $SAIL_SRC/_build/default/src/bin/sail.exe"

echo ""
echo "=== Setup complete ==="
echo "Sail:       $SAIL_SRC/_build/default/src/bin/sail.exe"
echo "isla-sail:  $ISLA_DIR/isla-sail/_build/default/sail_plugin_isla.cmxs"
echo "isla-footprint: $ISLA_DIR/target/release/isla-footprint"

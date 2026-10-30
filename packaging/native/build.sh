#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
native_root="$(cd "$(dirname "$0")/../.." && pwd)"
: "${PREFIX:?Set PREFIX to the installation prefix}"
native_stage="$(mktemp -d)"
trap 'rm -rf "$native_stage"' EXIT

# .mojoc contains non-elaborated Mojo; the consumer selects its supported target.
# Pin the compiler ABI, just as the channel recipe does.
case "$(mojo --version)" in
  'Mojo 1.0.0 ('*) ;;
  *) echo 'The native package requires Mojo 1.0.0' >&2; exit 1 ;;
esac
cd "$native_root"
sh tokenizer/tools/gen_unicode_table.sh
python3 "$native_root/packaging/native/stage.py" "$native_stage/source"
mkdir -p "$PREFIX/lib/mojo" "$PREFIX/share/anonlib"
# Rattler separates build tools from host libraries. MAX is installed into
# the host prefix, which need not be the compiler's own environment.
mojo precompile -I "$PREFIX/lib/mojo" "$native_stage/source/anonlib" -o "$native_stage/anonlib.mojoc"
cp "$native_stage/anonlib.mojoc" "$PREFIX/lib/mojo/anonlib.mojoc"
cp "$native_stage/source/native-sources.json" "$PREFIX/share/anonlib/"
cp "$native_root/LICENSE" "$PREFIX/share/anonlib/LICENSE"

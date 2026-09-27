#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

"$DIR/package.sh"

echo "🌟 Launching HyperNotch..."
open "$DIR/build/HyperNotch.app"

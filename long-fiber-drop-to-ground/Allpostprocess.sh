#!/usr/bin/env bash
# Convert DEM dumps for ParaView (same role as cyclone-separator Allpostprocess
# with SKIP_CFD_RECONSTRUCT=1).
set -euo pipefail

casePath="$(cd "$(dirname "$0")" && pwd)"
cd "$casePath"

if ! compgen -G "$casePath/post/dump*.liggghts_run" >/dev/null \
    && [ ! -f "$casePath/post/trajectory.dump" ]; then
    echo "ERROR: no post/dump*.liggghts_run (or trajectory.dump) found."
    echo "Run the case first, then re-run this script."
    exit 1
fi

echo "Converting DEM dumps for ParaView (rewrites particles.pvd)..."
"$casePath/dumpsToParaView" --step0 0 --dt 1e-6 "$@"

echo ""
echo "Open in ParaView:"
echo "  $casePath/post/particles.pvd"
echo "  $casePath/post/ground_mesh_0.stl   (optional)"
echo "In ParaView: File -> Reload Files if the case was already open."

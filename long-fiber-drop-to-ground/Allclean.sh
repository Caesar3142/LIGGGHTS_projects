#!/usr/bin/env bash
#===================================================================#
# Allclean: remove DEM runtime results for long-fiber-drop-to-ground.
# Keeps inputs: *.liggghts, *.stl, data/, dumpsToParaView, scripts.
#===================================================================#

set -euo pipefail

casePath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$casePath"

echo "Cleaning post/ and logs..."
rm -rf \
    post/dump*.liggghts_run \
    post/trajectory.dump \
    post/particles_* \
    post/particles.pvd \
    post/particles.series \
    post/frame_* \
    post/ground_mesh_*.stl \
    post/*.vtk \
    post/*.vtu \
    post/*.vtp \
    post/*.pvd \
    post/*.csv

rm -f log.liggghts screen.log log.* *.log

mkdir -p post
touch post/.gitkeep

echo "Clean done."

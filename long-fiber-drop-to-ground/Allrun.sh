#!/usr/bin/env bash
#===================================================================#
# Allrun: prepare post/ + run LIGGGHTS + Allpostprocess
# Run inside the liggghts:local Docker container.
#===================================================================#

set -euo pipefail

casePath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$casePath"

input="simple_dropping_to_ground.liggghts"

if ! command -v liggghts >/dev/null 2>&1; then
    echo "ERROR: liggghts not found in PATH."
    echo "Start the container first, then:"
    echo "  cd /simulation/long-fiber-drop-to-ground && ./Allrun.sh"
    exit 1
fi

if [ ! -f "$casePath/$input" ]; then
    echo "ERROR: missing input script: $input"
    exit 1
fi

if [ ! -f "$casePath/1x1m-ground.stl" ]; then
    echo "ERROR: missing ground mesh: 1x1m-ground.stl"
    exit 1
fi

if [ ! -f "$casePath/data/fiber.multisphere" ]; then
    echo "ERROR: missing fiber template: data/fiber.multisphere"
    exit 1
fi

echo "=== 1/3 Prepare (clean old results, mkdir post) ==="
"$casePath/Allclean.sh"

echo ""
echo "=== 2/3 Run LIGGGHTS ($input) ==="
liggghts -in "$input" -log log.liggghts | tee screen.log

echo ""
echo "=== 3/3 Post-process (dump*.liggghts_run -> particles.pvd) ==="
"$casePath/Allpostprocess.sh"

echo ""
echo "Allrun finished."
echo "  ParaView: $casePath/post/particles.pvd"
echo "  Ground:   $casePath/post/ground_mesh_0.stl"

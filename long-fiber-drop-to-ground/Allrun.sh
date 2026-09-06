#!/usr/bin/env bash
#===================================================================#
# Allrun: prepare post/ + run LIGGGHTS + Allpostprocess
# Requires liggghts-flex:local (bonded / flexible fibers).
#===================================================================#

set -euo pipefail

casePath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$casePath"

input="simple_dropping_to_ground.liggghts"

if ! command -v liggghts >/dev/null 2>&1; then
    echo "ERROR: liggghts not found in PATH."
    echo "Build and start the flexible-fiber image:"
    echo "  docker build --platform linux/amd64 -f Dockerfile.flexible -t liggghts-flex:local ."
    echo "  docker run -it --rm --platform linux/amd64 \\"
    echo "    -v ~/Documents_Local/GitHub/LIGGGHTS_projects:/simulation \\"
    echo "    liggghts-flex:local"
    echo "  cd /simulation/long-fiber-drop-to-ground && ./Allrun.sh"
    exit 1
fi

# Stock liggghts:local has no bond/gran — fail early with a clear message
probe="$(mktemp)"
cat > "$probe" <<'EOF'
units si
atom_style hybrid granular bond/gran n_bondtypes 1 bonds_per_atom 2
EOF
probe_out="$(liggghts -in "$probe" -log none 2>&1 || true)"
rm -f "$probe"
if echo "$probe_out" | grep -q "Invalid atom style"; then
    echo "ERROR: this liggghts binary has no bond/gran (rigid-only build)."
    echo "Use image liggghts-flex:local from Dockerfile.flexible, not liggghts:local."
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

echo "=== 1/3 Prepare (clean old results, mkdir post) ==="
"$casePath/Allclean.sh"

echo ""
echo "=== 2/3 Run LIGGGHTS ($input) — flexible bonded fibers ==="
liggghts -in "$input" -log log.liggghts | tee screen.log

echo ""
echo "=== 3/3 Post-process (dump*.liggghts_run -> particles.pvd) ==="
"$casePath/Allpostprocess.sh"

echo ""
echo "Allrun finished."
echo "  ParaView: $casePath/post/particles.pvd"
echo "  Ground:   $casePath/post/ground_mesh_0.stl"
echo "  Tip: color by mol; fibers should bend on impact (soft bond_youngs)."

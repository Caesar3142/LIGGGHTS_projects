#!/bin/bash

#===================================================================#
# Allrun: cyclone-separator CFD-DEM (CFDEM + LIGGGHTS)
#
# Requires the cfdem:local Docker image (see ../Dockerfile.cfdem), NOT liggghts:local.
#===================================================================#

set -euo pipefail

casePath="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: '$1' not found."
        echo "This case needs OpenFOAM + CFDEMcoupling."
        echo "Exit this container and start:"
        echo "  docker run -it --rm --platform linux/amd64 \\"
        echo "    -v ~/Documents_Local/GitHub/LIGGGHTS_projects:/simulation \\"
        echo "    cfdem:local"
        echo "Build once with: docker build --platform linux/amd64 -f Dockerfile.cfdem -t cfdem:local ."
        exit 1
    fi
}

require_cmd blockMesh
require_cmd snappyHexMesh
require_cmd checkMesh
require_cmd cfdemSolverPiso
require_cmd parCFDDEMrun

if [ -z "${CFDEM_LIGGGHTS_EXEC:-}" ] || [ ! -x "${CFDEM_LIGGGHTS_EXEC}" ]; then
    echo "ERROR: CFDEM_LIGGGHTS_EXEC is not set or not executable."
    echo "Use the cfdem:local image (Dockerfile.cfdem), not liggghts:local."
    exit 1
fi

mkdir -p "$casePath/DEM/post/restart" "$casePath/CFD/couplingFiles"
# parCFDDEMrun does: rm couplingFiles/*
touch "$casePath/CFD/couplingFiles/.keep"

# Build the STL-fitted cyclone mesh if a valid one does not exist.
boundaryFile="$casePath/CFD/constant/polyMesh/boundary"
if [ -f "$boundaryFile" ] &&
   grep -q "body" "$boundaryFile" &&
   grep -q "inlet" "$boundaryFile" &&
   grep -q "outlet" "$boundaryFile"; then
    echo "Cyclone mesh already exists - using it"
else
    echo "Building cyclone mesh..."
    rm -rf "$casePath/CFD/constant/polyMesh"
    cd "$casePath/CFD"
    blockMesh
    snappyHexMesh -overwrite
    checkMesh
fi

# The cyclone starts empty. LIGGGHTS creates particles periodically at the
# inlet during the coupled run, so no packed-bed restart is required.
"$casePath/parCFDDEMrun.sh"
